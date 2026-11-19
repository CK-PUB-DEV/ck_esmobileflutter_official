import 'package:pushtrial/core/api/api_version.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pushtrial/core/api/api.dart';
import 'package:pushtrial/models/enrolled_student.dart';
import 'package:pushtrial/models/ledger.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/models/user_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';

class CarouselCard extends StatefulWidget {
  const CarouselCard({super.key, this.schoolColor});

  /// The logged-in school's colour; null falls back to the theme colour.
  final Color? schoolColor;

  @override
  State<CarouselCard> createState() => _CarouselCardState();
}

class _CarouselCardState extends State<CarouselCard> {
  String id = '0';
  String? sid;
  int syid = 0;
  int semid = 0;
  String syDesc = '';
  String sem = '';
  String totalBalance = 'PHP 0.00';
  // Shown instead of a misleading "₱ 0.00" while the balance loads or when it can't be loaded.
  bool _balanceLoading = true;
  String? _balanceError;
  bool _isBalanceVisible = true;

  List<Ledger> data = [];
  List<EnrolledStud> enrolledstud = [];
  User user = UserData.myUser;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  String _schoolVersion = 'v1';

  Future<void> _initializeData() async {
    await getUser();

    // The ledger needs the selected school year from enrollment.
    await _guard('enrollment', getEnrolledStud);

    final prefs = await SharedPreferences.getInstance();
    _schoolVersion = await ApiVersion.billingVersion();

    if (_schoolVersion == 'v2') {
      await getLedgerV2();
    } else {
      try {
        await getLedger();
      } catch (e) {
        print('Ledger error: $e');
        _setBalanceError('Balance is unavailable right now.');
      }
    }
  }

  // One failed call shouldn't stop the others or leave the card stuck loading.
  Future<void> _guard(String label, Future<void> Function() load) async {
    try {
      await load();
    } catch (e) {
      print('Carousel $label error: $e');
    }
  }

  void _setBalance(String balance) {
    if (!mounted) return;
    setState(() {
      totalBalance = balance;
      _balanceLoading = false;
      _balanceError = null;
    });
  }

  void _setBalanceError(String message) {
    if (!mounted) return;
    setState(() {
      _balanceLoading = false;
      _balanceError = message;
    });
  }

  void _toggleBalanceVisibility() {
    setState(() => _isBalanceVisible = !_isBalanceVisible);
  }

  // Prefer the server's own reason (e.g. "Student Ledger is currently unavailable.").
  String _serverMessage(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded['message'] is String)
        return decoded['message'];
    } catch (_) {}
    return 'Balance is unavailable right now.';
  }

  Future<void> getUser() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final jsonStr = preferences.getString('user');
    if (jsonStr != null) {
      setState(() {
        user = User.fromJson(jsonDecode(jsonStr));
        sid = user.sid;
        id = user.id.toString();
      });
    }
  }

  Future<void> getEnrolledStud() async {
    final response = await CallApi().getEnrolledStud(id);
    final decodedJson = json.decode(response.body);

    if (decodedJson is Map<String, dynamic>) {
      Iterable list = decodedJson['enrolledstud_info'];
      enrolledstud = list.map((e) => EnrolledStud.fromJson(e)).toList();

      if (enrolledstud.isNotEmpty) {
        final latestInfo = enrolledstud.last;
        // setState so "SY:" and the enrollment card show now, not only once the ledger loads.
        if (mounted) {
          setState(() {
            syid = latestInfo.syid;
            semid = latestInfo.semid;
            syDesc = latestInfo.sydesc;
            sem = latestInfo.semester;
          });
        }
        print(
          'EnrolledStud - id: $id, syid: $syid, semid: $semid, syDesc: $syDesc',
        );
      }
    }
  }

  Future<void> getLedgerV2() async {
    try {
      final response = await CallApi()
          .getV2StudLedger(id, syid, semid)
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        _setBalanceError(_serverMessage(response.body));
        return;
      }
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      if (decoded['success'] != true) {
        _setBalanceError(_serverMessage(response.body));
        return;
      }
      final fees = decoded['school_fees'] as List<dynamic>? ?? [];
      double total = 0;
      for (final fee in fees) {
        total += (fee['total_balance'] ?? 0).toDouble();
      }
      _setBalance('PHP ${total.toStringAsFixed(2)}');
    } catch (e) {
      print('V2 ledger error: $e');
      _setBalanceError('Could not load balance. Check your connection.');
    }
  }

  Future<void> getLedger() async {
    print('getLedger called with - id: $id, syid: $syid, semid: $semid');

    final dynamic response;
    try {
      response = await CallApi()
          // Basic-ed enrollments carry semid 0, which the v1 ledger reads as "no rows";
          // the Billing page defaults to semester 1, so do the same here.
          .getStudLedger(id, syid, semid == 0 ? 1 : semid)
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      print('Ledger error: $e');
      _setBalanceError('Could not load balance. Check your connection.');
      return;
    }

    // Print raw response data
    print('Response Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode != 200) {
      print('Error: API returned status ${response.statusCode}');
      _setBalanceError(_serverMessage(response.body));
      return;
    }

    final list = json.decode(response.body);
    print('Decoded JSON: $list');

    data = (list as List).map((e) => Ledger.fromJson(e)).toList();
    print('Parsed data: $data');
    print('Data length: ${data.length}');

    // Debug: Print each entry's particulars field to see exact content
    for (int i = 0; i < data.length; i++) {
      print(
        'Entry $i: particulars="${data[i].particulars}", balance="${data[i].balance}"',
      );
    }

    final total = data.firstWhere(
      (e) {
        final isTotal = e.particulars.trim().toUpperCase().startsWith('TOTAL:');
        print('Checking: "${e.particulars}" -> isTotal=$isTotal');
        return isTotal;
      },
      orElse: () {
        print('TOTAL not found, using default');
        return Ledger(
          particulars: 'TOTAL:',
          balance: '0.00',
          payment: '0.00',
          amount: '',
        );
      },
    );

    print(
      'Final Total found: particulars="${total.particulars}", balance="${total.balance}"',
    );

    _setBalance('PHP ${total.balance}');
  }

  @override
  Widget build(BuildContext context) {
    final latestInfo = enrolledstud.lastWhere(
      (element) => element.sydesc == syDesc,
      orElse: () => EnrolledStud(
        id: 0,
        studid: 0,
        syid: 0,
        semid: 0,
        dateenrolled: '',
        levelid: 0,
        sectionid: 0,
        strandid: 0,
        studstatus: 0,
        levelname: '',
        strandname: '',
        description: '',
        courseDesc: '',
        semester: '',
        sectionname: '',
        sydesc: '',
      ),
    );
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;
    final scheme = theme.colorScheme;
    final sidText = sid?.isNotEmpty == true ? sid! : 'Student ID unavailable';
    final program = latestInfo.courseDesc.isNotEmpty
        ? latestInfo.courseDesc
        : latestInfo.strandname;
    final balanceText = _balanceError ??
        Fmt.money(totalBalance.replaceFirst('PHP', '').trim());
    final tone = SchoolTone(context, widget.schoolColor ?? scheme.primary);
    final onSolid = tone.onSolid;

    // Neutral pill for secondary facts on the white card; colour stays on the filled surfaces.
    Widget pill(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs + 2),
      decoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: text.smallStrong,
      ),
    );

    return Column(
      children: [
        // Hero: the balance is the one number a parent opens the app for, so it gets the fill.
        SolidCard(
          tone: tone,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(LucideIcons.wallet, color: onSolid, size: IconSize.row),
                  Text(
                    'Current balance',
                    style: text.smallStrong.copyWith(
                      color: onSolid.withValues(alpha: 0.85),
                    ),
                  ),
                  if (syDesc.isNotEmpty)
                    SchoolPill(
                      'SY $syDesc${sem.isNotEmpty ? ' · $sem' : ''}',
                      tone,
                      onCard: true,
                    ),
                ],
              ),
              Gap.hLg,
              if (_balanceLoading)
                SkeletonBox(height: 32, width: 140)
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _balanceError == null && !_isBalanceVisible
                          ? Semantics(
                              label: 'Balance hidden',
                              child: ExcludeSemantics(
                                child: Text(
                                  '••••••••',
                                  style: text.h1.copyWith(color: onSolid),
                                ),
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                balanceText,
                                maxLines: 1,
                                style: _balanceError == null
                                    ? text.h1.copyWith(color: onSolid)
                                    : text.p.copyWith(
                                        color: onSolid.withValues(alpha: 0.9),
                                      ),
                              ),
                            ),
                    ),
                    if (_balanceError == null)
                      Semantics(
                        button: true,
                        label: _isBalanceVisible
                            ? 'Hide balance'
                            : 'Show balance',
                        child: Tooltip(
                          message: _isBalanceVisible
                              ? 'Hide balance'
                              : 'Show balance',
                          child: ShadButton.ghost(
                            onPressed: _toggleBalanceVisibility,
                            child: Icon(
                              _isBalanceVisible
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                              color: onSolid,
                              size: IconSize.row,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        RoundedCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.school, color: scheme.foreground, size: IconSize.row),
                  Gap.wSm,
                  Expanded(child: Text('Enrollment', style: text.muted)),
                  SchoolPill(sidText, tone),
                ],
              ),
              if (latestInfo.levelname.isNotEmpty ||
                  program.isNotEmpty ||
                  latestInfo.sectionname.isNotEmpty) ...[
                Gap.hLg,
                if (latestInfo.levelname.isNotEmpty)
                  Text(latestInfo.levelname, style: text.h4),
                Gap.hSm,
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    if (program.isNotEmpty) pill(program),
                    if (latestInfo.sectionname.isNotEmpty)
                      pill(latestInfo.sectionname),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
