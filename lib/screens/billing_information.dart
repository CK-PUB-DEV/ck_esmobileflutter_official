import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:pushtrial/models/year_sem.dart';
import 'package:pushtrial/widgets/ui/ui.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushtrial/api/api.dart';
import 'package:pushtrial/models/ledger.dart';
import 'dart:convert';
import 'package:pushtrial/models/school_info.dart';
import 'package:pushtrial/models/enrolled_stud.dart';
import 'package:screen_protector/screen_protector.dart';

class BillingInformationPage extends StatefulWidget {
  const BillingInformationPage({super.key});

  @override
  State<BillingInformationPage> createState() => BillingInformationState();
}

class BillingInformationState extends State<BillingInformationPage> {
  String id = '0';
  int syid = 1;
  int semid = 1;
  int levelid = 0;
  String selectedYear = '';
  String selectedSem = '';
  List<String> years = [];
  List<Ledger> data = [];

  String syDesc = '';
  String sem = '';
  String totalBalance = 'Php 0.00';
  String totalPayment = 'Php 100.00';
  bool loading = true;
  List<SchoolYear> schoolYear = [];
  List<Sem> schoolSem = [];
  List<EnrolledStud> enrolledstud = [];
  List<SchoolInfo> schoolInfo = [];
  Color schoolColor = Color.fromARGB(0, 255, 255, 255);

  @override
  void initState() {
    super.initState();
    if (!kDebugMode) ScreenProtector.preventScreenshotOn(); // debug builds stay capturable for testing
    getUser();
    getSchoolInfo();
    getYearandSem();

    print('levelid: $levelid');
  }

  @override
  void dispose() {
    ScreenProtector.preventScreenshotOff();
    super.dispose();
  }

  Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 7 || hexString.length == 9) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Future<void> getSchoolInfo() async {
    final response = await CallApi().getSchoolInfo();

    final parsedResponse = json.decode(response.body);
    if (parsedResponse is List) {
      setState(() {
        schoolInfo = parsedResponse
            .map((model) => SchoolInfo.fromJson(model))
            .toList()
            .cast<SchoolInfo>();

        schoolColor = hexToColor(schoolInfo[0].schoolcolor);
      });
    }
  }

  // The v1 ledger sends amounts as ready-made strings ("1,200.00", sometimes blank on header
  // rows). Format real numbers the same way as everywhere else and leave anything else as sent.
  String _amount(String raw) {
    final cleaned = raw.replaceAll('Php', '').replaceAll(',', '').trim();
    if (cleaned.isEmpty) return '';
    return num.tryParse(cleaned) == null ? raw : Fmt.money(cleaned);
  }

  String _totalText(String raw) {
    final formatted = _amount(raw);
    return formatted.isEmpty ? Fmt.money(0) : formatted;
  }

  void _showError(String message) {
    if (!mounted) return;
    showShadDialog(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: const Text('Error'),
        description: Text(message),
        actions: [
          ShadButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const AppPage(title: 'Billing information', body: LoadingSkeleton());
    }
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;
    final showSem = levelid == 14 || levelid == 15 || levelid >= 17;

    return AppPage(
      title: 'Billing information',
      children: [
        Row(
          children: [
            Expanded(
              child: ShadSelect<String>(
                placeholder: const Text('School year'),
                initialValue: selectedYear.isNotEmpty ? selectedYear : null,
                options: [
                  for (final option in schoolYear)
                    ShadOption(value: option.id.toString(), child: Text(option.sydesc)),
                ],
                selectedOptionBuilder: (context, value) => Text(
                  schoolYear
                      .firstWhere((y) => y.id.toString() == value, orElse: () => schoolYear.first)
                      .sydesc,
                ),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedYear = value;
                    syid = int.parse(selectedYear);
                  });
                  if (selectedSem.isNotEmpty) getLedger();
                },
              ),
            ),
            if (showSem) ...[
              Gap.wSm,
              Expanded(
                child: ShadSelect<String>(
                  placeholder: const Text('Semester'),
                  initialValue: selectedSem.isNotEmpty ? selectedSem : null,
                  options: [
                    for (final option in schoolSem)
                      ShadOption(value: option.id.toString(), child: Text(option.semester)),
                  ],
                  selectedOptionBuilder: (context, value) => Text(
                    schoolSem
                        .firstWhere((s) => s.id.toString() == value, orElse: () => schoolSem.first)
                        .semester,
                  ),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      selectedSem = value;
                      semid = int.parse(selectedSem);
                    });
                    if (selectedYear.isNotEmpty) getLedger();
                  },
                ),
              ),
            ],
          ],
        ),
        Gap.hLg,
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Total balance',
                      value: _totalText(totalBalance),
                      icon: LucideIcons.wallet,
                    ),
                  ),
                  if (selectedYear.isNotEmpty && selectedSem.isNotEmpty)
                    Flexible(
                      child: Text(
                        "SY: ${schoolYear.isNotEmpty ? schoolYear.firstWhere((year) => year.id.toString() == selectedYear, orElse: () => schoolYear.first).sydesc : ''}"
                        "${levelid > 13 && schoolSem.isNotEmpty ? "\nSem: ${schoolSem.firstWhere((sem) => sem.id.toString() == selectedSem, orElse: () => schoolSem.first).semester}" : ""}",
                        textAlign: TextAlign.end,
                        style: text.muted,
                      ),
                    ),
                ],
              ),
              Gap.hLg,
              Divider(height: 1, color: theme.colorScheme.border),
              Gap.hLg,
              StatTile(
                label: 'Payments',
                value: _totalText(totalPayment),
                icon: LucideIcons.banknote,
              ),
            ],
          ),
        ),
        if (schoolInfo.isNotEmpty && schoolInfo[0].abbreviation.toUpperCase() == 'SBC')
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.info, size: IconSize.inline, color: theme.colorScheme.mutedForeground),
                Gap.wSm,
                Expanded(
                  child: Text(
                    'Non-tuition / walk-in cash payments may not be reflected in the total.',
                    style: text.muted,
                  ),
                ),
              ],
            ),
          ),
        const SectionHeader('Particulars'),
        if (data.isEmpty)
          const EmptyState(title: 'No billing records', message: 'Nothing to show for this school year.')
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < data.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: theme.colorScheme.border),
                  _buildLedgerRow(data[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLedgerRow(Ledger ledger) {
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;
    final isTotal = ledger.particulars.startsWith('TOTAL:');
    final color = ledger.isVoided ? theme.colorScheme.mutedForeground : theme.colorScheme.foreground;
    final decoration = ledger.isVoided ? TextDecoration.lineThrough : TextDecoration.none;
    final weight = isTotal ? FontWeight.w600 : FontWeight.w400;
    final amount = _amount(ledger.amount);
    final payment = _amount(ledger.payment);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ledger.particulars,
                  style: text.small.copyWith(color: color, fontWeight: weight, decoration: decoration),
                ),
              ),
              if (ledger.isVoided) ...[
                Gap.wSm,
                const StatusBadge('Void', status: AppStatus.danger),
              ],
            ],
          ),
          if (amount.isNotEmpty || payment.isNotEmpty) ...[
            Gap.hXs,
            Wrap(
              spacing: Gap.lg,
              runSpacing: Gap.xs,
              children: [
                if (amount.isNotEmpty) _labelValue('Amount', amount, color, weight, decoration),
                if (payment.isNotEmpty) _labelValue('Payments', payment, color, weight, decoration),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _labelValue(String label, String value, Color color, FontWeight weight, TextDecoration decoration) {
    final text = ShadTheme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: text.muted),
        Text(
          value,
          style: text.small.copyWith(color: color, fontWeight: weight, decoration: decoration),
        ),
      ],
    );
  }

  getYearandSem() async {
    final response = await CallApi().getYearandSem();
    final Map<String, dynamic> responseData = json.decode(response.body);

    schoolYear = (responseData['sy'] as List)
        .map((data) => SchoolYear.fromJson(data))
        .toList();
    schoolSem = (responseData['semester'] as List)
        .map((data) => Sem.fromJson(data))
        .toList();

    schoolYear.sort((a, b) => a.sydesc.compareTo(b.sydesc));

    // Fixed: Use firstWhere with error handling to safely find active items
    SchoolYear? activeYear;
    Sem? activeSem;
    try {
      activeYear = schoolYear.firstWhere((year) => year.isactive == 1);
    } catch (e) {
      activeYear = null;
    }
    try {
      activeSem = schoolSem.firstWhere((sem) => sem.isactive == 1);
    } catch (e) {
      activeSem = null;
    }

    if (activeYear != null && activeSem != null) {
      selectedYear = activeYear.id.toString();
      selectedSem = activeSem.id.toString();
    } else if (schoolYear.isNotEmpty && schoolSem.isNotEmpty) {
      selectedYear = schoolYear.last.id.toString();
      selectedSem = schoolSem.first.id.toString();
    } else {
      // Fallback to empty or default values
      selectedYear = '';
      selectedSem = '';
      return; // Exit early if no data available
    }

    syid = int.parse(selectedYear);
    semid = int.parse(selectedSem);

    setState(() {
      getLedger();
    });
  }

  Future<void> getUser() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final json = preferences.getString('studid');

    if (json != null) {
      setState(() {
        id = json;
        loading = true;
      });
      await getEnrollment();
      await getLedger();
    }
  }

  getEnrollment() async {
    final response = await CallApi().getEnrolledStud(id);
    final List<dynamic> enrollmentList = json.decode(
      response.body,
    )['enrolledstud_info'];

    setState(() {
      enrolledstud = enrollmentList
          .map((model) => EnrolledStud.fromJson(model))
          .toList();
      if (enrolledstud.isNotEmpty) {
        levelid = enrolledstud.last.levelid;
      }
    });
  }

  Future<void> getLedger() async {
    try {
      final response = await CallApi().getStudLedger(id, syid, semid);

      // Check if the response status is successful
      if (response.statusCode != 200) {
        print('Error: API returned status ${response.statusCode}');
        setState(() {
          loading = false;
        });

        _showError(
          'Failed to load billing information. The server returned an error (Status: ${response.statusCode}). Please try again later or contact support.',
        );
        return;
      }

      setState(() {
        Iterable list = json.decode(response.body);
        data = list.map((model) => Ledger.fromJson(model)).toList();

        // Fixed: Use firstWhere with error handling to prevent "Bad state: no element"
        Ledger? totalLedger;
        try {
          totalLedger = data.firstWhere(
            (item) => item.particulars.startsWith('TOTAL:'),
          );
        } catch (e) {
          totalLedger = null;
        }

        if (totalLedger != null) {
          totalBalance = 'Php ${totalLedger.balance}';
          totalPayment = 'Php ${totalLedger.payment}';
        } else {
          // Default values if TOTAL row is not found
          totalBalance = 'Php 0.00';
          totalPayment = 'Php 0.00';
        }

        loading = false;
      });
    } catch (e) {
      print('Error fetching ledger: $e');
      setState(() {
        loading = false;
      });

      // Show error dialog for any exception
      _showError(
        'An error occurred while loading billing information: ${e.toString()}. Please check your internet connection and try again.',
      );
    }
  }
}
