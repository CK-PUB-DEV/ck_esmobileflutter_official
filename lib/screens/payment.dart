import 'package:flutter/material.dart';
import 'payment_form.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:pushtrial/models/transactions.dart';
import 'package:pushtrial/api/api.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/models/user_data.dart';
import 'package:pushtrial/models/onlinepayments.dart';
import 'package:pushtrial/models/school_info.dart';
import 'package:pushtrial/models/year_sem.dart';
import 'package:pushtrial/widgets/ui/ui.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});
  @override
  State<PaymentPage> createState() => PaymentPageState();
}

class PaymentPageState extends State<PaymentPage> {
  // Slow responses can finish after the screen was closed; skip the update then.
  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  static const _tabTransactions = 'transactions';
  static const _tabUploaded = 'uploaded';
  final ShadTabsController<String> _tabs = ShadTabsController(value: _tabTransactions);

  User user = UserData.myUser;
  int syid = 0; // 0 means "All School Years"; set to the current school year once years load
  int id = 0;
  String sid = '0';
  String selectedYear = '0';

  /// Semester shown (semester.id); 0 = every semester of the chosen year.
  int semFilter = 0;

  /// Everything the server returned; [trans] and [payments] are these after the filters.
  List<Transactions> _allTrans = [];
  List<Payments> _allPayments = [];
  List<Transactions> trans = [];
  List<Payments> payments = [];
  List<SchoolYear> schoolYear = [];
  List<Sem> schoolSem = [];

  List<SchoolInfo> schoolInfo = [];
  Color schoolColor = const Color.fromARGB(0, 255, 255, 255);

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

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeDummyData() {
    // Initialize with dummy school year data
    schoolYear = [
      SchoolYear(id: 1, sydesc: '2024-2025', sdate: '2024-06-01', edate: '2025-03-31', isactive: 1),
      SchoolYear(id: 2, sydesc: '2023-2024', sdate: '2023-06-01', edate: '2024-03-31', isactive: 0),
      SchoolYear(id: 3, sydesc: '2022-2023', sdate: '2022-06-01', edate: '2023-03-31', isactive: 0),
    ];
  }

  Future<void> _initializeData() async {
    await getUser();
    await getYearandSem();
    getOnlinePayments();
    getSchoolInfo();
    getTransactions();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> getUser() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final json = preferences.getString('user');
    user = json == null ? UserData.myUser : User.fromJson(jsonDecode(json));
    print('User data in payment section screen: $user');

    setState(() {
      id = user.id;
      sid = user.sid!;
    });
  }

  Future<void> getYearandSem() async {
    try {
      final response = await CallApi().getYearandSem();
      final Map<String, dynamic> responseData = json.decode(response.body);

      schoolYear = (responseData['sy'] as List)
          .map((data) => SchoolYear.fromJson(data))
          .toList();
      schoolSem = (responseData['semester'] as List)
          .map((data) => Sem.fromJson(data))
          .toList();

      schoolYear.sort((a, b) => a.sydesc.compareTo(b.sydesc));

      // Start on the current school year; "All school years" stays one tap away.
      final current = schoolYear.where((y) => y.isactive == 1).toList();
      setState(() {
        syid = current.isEmpty ? 0 : current.last.id;
        selectedYear = '$syid';
        semFilter = 0;
      });
    } catch (e) {
      print('Error loading school year and semester: $e');
      // Fallback to dummy data if API fails
      _initializeDummyData();
    }
  }

  getTransactions() async {
    final response = await CallApi().getTransactions(id);

    if (response.statusCode == 200) {
      if (response.body.isEmpty) {
        print('No Transactions found');
        return;
      }
      Iterable list = json.decode(response.body);

      final all = list.map((model) => Transactions.fromJson(model)).toList();
      // Newest first; unreadable dates last.
      all.sort((a, b) {
        final da = DateTime.tryParse(a.transdate);
        final db = DateTime.tryParse(b.transdate);
        if (da == null || db == null) return da == null ? (db == null ? 0 : 1) : -1;
        return db.compareTo(da);
      });
      setState(() {
        _allTrans = all;
        _applyFilters();
      });
    }
  }

  /// Recomputes [trans] and [payments] from the full lists for the chosen year and semester.
  /// Call inside setState.
  void _applyFilters() {
    bool keep(int itemSy, int itemSem) =>
        (syid == 0 || itemSy == syid) && (semFilter == 0 || syid == 0 || itemSem == semFilter);
    trans = _allTrans.where((t) => keep(t.syid, t.semid)).toList();
    payments = _allPayments.where((p) => keep(p.syid, p.semid)).toList();
  }

  /// The semesters the chosen school year has payments in, in order. The semester buttons show
  /// only when there is more than one (college and senior high); basic ed never sees them.
  List<int> get _semestersInYear {
    if (syid == 0) return const [];
    final ids = <int>{
      for (final t in _allTrans)
        if (t.syid == syid && t.semid > 0) t.semid,
      for (final p in _allPayments)
        if (p.syid == syid && p.semid > 0) p.semid,
    }.toList()
      ..sort();
    return ids;
  }

  String _semName(int semid, {bool short = false}) {
    final name = schoolSem.where((s) => s.id == semid).map((s) => s.semester).firstOrNull ??
        const {1: '1st Semester', 2: '2nd Semester', 3: 'Summer'}[semid] ??
        'Semester $semid';
    return short ? name.replaceAll('Semester', 'Sem') : name;
  }

  /// "2026-2027 · 1st Semester", "2026-2027" or "All school years".
  String get _scopeLabel {
    if (syid == 0) return 'All school years';
    final year = _yearLabel('$syid');
    return semFilter == 0 ? year : '$year · ${_semName(semFilter)}';
  }

  /// True when the student pays per semester (more than one semester in any year): their
  /// payments under "All school years" are grouped by school year and semester, not by month.
  bool get _paysPerSemester {
    final semsByYear = <int, Set<int>>{};
    for (final t in _allTrans) {
      semsByYear.putIfAbsent(t.syid, () => {}).add(t.semid);
    }
    return semsByYear.values.any((s) => s.length > 1);
  }

  getOnlinePayments() async {
    final response = await CallApi().getOnlinePayments(sid);

    if (response.statusCode == 200) {
      if (response.body.isEmpty) {
        print('No data returned');
        return;
      }
      Iterable list = json.decode(response.body);
      final all = list.map((model) => Payments.fromJson(model)).toList();
      setState(() {
        _allPayments = all;
        _applyFilters();
      });
    }
  }

  String _yearLabel(String value) {
    if (value == '0') return 'All school years';
    return schoolYear.where((y) => y.id.toString() == value).map((y) => y.sydesc).firstOrNull ??
        'Other school year';
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild on tab switches; the school-year selector keeps its own state across rebuilds.
    return ListenableBuilder(
      listenable: _tabs,
      builder: (context, _) => AppPage(
        title: 'Payment transactions',
        onRefresh: () async {
          if (_tabs.selected == _tabUploaded) {
            await getOnlinePayments();
          } else {
            await getTransactions();
          }
        },
        children: [
          ShadSelect<String>(
            // Rebuilt once the years arrive, so it opens on the current school year.
            key: ValueKey('years-${schoolYear.length}'),
            placeholder: const Text('Select school year'),
            initialValue: selectedYear,
            options: [
              const ShadOption(value: '0', child: Text('All school years')),
              for (final option in schoolYear.reversed)
                ShadOption(value: option.id.toString(), child: Text(option.sydesc)),
            ],
            selectedOptionBuilder: (context, value) => Text(_yearLabel(value)),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                selectedYear = value;
                syid = int.parse(value);
                semFilter = 0;
                _applyFilters();
              });
            },
          ),
          if (_semestersInYear.length > 1) ...[
            Gap.hSm,
            Row(
              children: [
                for (final sem in [0, ..._semestersInYear]) ...[
                  Expanded(
                    child: sem == semFilter
                        ? ShadButton.secondary(
                            size: ShadButtonSize.sm,
                            onPressed: () {},
                            child: Text(sem == 0 ? 'All' : _semName(sem, short: true)),
                          )
                        : ShadButton.ghost(
                            size: ShadButtonSize.sm,
                            onPressed: () => setState(() {
                              semFilter = sem;
                              _applyFilters();
                            }),
                            child: Text(sem == 0 ? 'All' : _semName(sem, short: true)),
                          ),
                  ),
                  if (sem != _semestersInYear.last) Gap.wXs,
                ],
              ],
            ),
          ],
          Gap.hMd,
          ShadTabs<String>(
            controller: _tabs,
            tabs: const [
              ShadTab(value: _tabTransactions, child: Text('Transactions')),
              ShadTab(value: _tabUploaded, child: Text('Uploaded payments')),
            ],
          ),
          Gap.hMd,
          if (_tabs.selected == _tabUploaded) ..._buildUploadedPaymentTab() else ..._buildTransactionsTab(),
        ],
      ),
    );
  }

  AppStatus _statusTone(String status) {
    switch (status) {
      case 'Approved':
      case 'Processed':
        return AppStatus.success;
      case 'On Process':
        return AppStatus.warning;
      case 'Not Approved':
      case 'Canceled':
        return AppStatus.danger;
      default:
        return AppStatus.neutral;
    }
  }

  // Round muted badge behind a payment's icon or logo.
  Widget _leading(Widget child) {
    final theme = ShadTheme.of(context);
    return Container(
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.muted),
      alignment: Alignment.center,
      child: child,
    );
  }

  List<Widget> _buildUploadedPaymentTab() {
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;

    payments.sort(
      (a, b) => DateTime.parse(
        b.paymentDate,
      ).compareTo(DateTime.parse(a.paymentDate)),
    );

    return [
      ShadButton(
        width: double.infinity,
        leading: const Icon(LucideIcons.plus, size: IconSize.row),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PaymentForm()),
          );
        },
        child: const Text('Upload payment'),
      ),
      Gap.hLg,
      if (payments.isEmpty)
        const EmptyState(
          title: 'No uploaded payments found',
          message: 'Payments you upload will appear here.',
          icon: LucideIcons.receipt,
        )
      else
        for (final payment in payments)
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _leading(
                  payment.description == 'BANK'
                      ? Icon(LucideIcons.landmark, size: IconSize.row, color: theme.colorScheme.foreground)
                      : Image.asset(
                          payment.description == 'GCASH' ? 'assets/gcash.jpg' : 'assets/palawan.png',
                          height: 44,
                          width: 44,
                          fit: BoxFit.cover,
                        ),
                ),
                Gap.wMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Fmt.date(DateTime.parse(payment.paymentDate)), style: text.muted),
                      Gap.hXs,
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              payment.description,
                              style: text.p.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Gap.wSm,
                          Text(
                            Fmt.money(double.parse(payment.amount)),
                            style: text.p.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Gap.hSm,
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Ref. no. ${payment.refNum}',
                              style: text.small,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Gap.wSm,
                          StatusBadge(payment.getStatus(), status: _statusTone(payment.getStatus())),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    ];
  }

  List<Widget> _buildTransactionsTab() {
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;

    if (trans.isEmpty) {
      return const [
        EmptyState(
          title: 'No transactions found',
          message: 'Your payments will appear here.',
          icon: LucideIcons.receipt,
        ),
      ];
    }

    double amountOf(Transactions t) => double.tryParse(t.amountpaid.replaceAll(',', '')) ?? 0;

    // Students who pay per semester see "All school years" grouped by school year and semester,
    // newest first, since that is how their fees are billed. Otherwise group by month (trans is
    // already sorted newest first); payments without a readable date go last under "Other".
    final groups = <String, List<Transactions>>{};
    if (syid == 0 && _paysPerSemester) {
      final ordered = [...trans]..sort((a, b) {
          final byYear = _yearLabel('${b.syid}').compareTo(_yearLabel('${a.syid}'));
          return byYear != 0 ? byYear : b.semid.compareTo(a.semid);
        });
      for (final t in ordered) {
        groups.putIfAbsent('${_yearLabel('${t.syid}')} · ${_semName(t.semid)}', () => []).add(t);
      }
    } else {
      for (final t in trans) {
        final date = DateTime.tryParse(t.transdate);
        final key = date == null ? 'Other' : DateFormat('MMMM y').format(date);
        groups.putIfAbsent(key, () => []).add(t);
      }
    }
    final total = trans.fold<double>(0, (sum, t) => sum + amountOf(t));

    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_scopeLabel, style: text.muted),
            Gap.hXs,
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: Text(Fmt.money(total), style: text.h3)),
                Text(
                  '${trans.length} payment${trans.length == 1 ? '' : 's'}',
                  style: text.muted,
                ),
              ],
            ),
            Text('Total paid', style: text.muted),
          ],
        ),
      ),
      for (final entry in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(entry.key, style: text.p.copyWith(fontWeight: FontWeight.w600)),
              ),
              Text(
                Fmt.money(entry.value.fold<double>(0, (sum, t) => sum + amountOf(t))),
                style: text.muted,
              ),
            ],
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < entry.value.length; i++) ...[
                if (i > 0) Divider(height: 1, color: theme.colorScheme.border),
                _transactionRow(entry.value[i], amountOf(entry.value[i])),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  /// "Cash payment" over "OR 68539-M · Oct 19, 2026", amount on the right. Only the date is shown:
  /// some schools' cashier records keep times on a 12-hour clock without AM/PM, so the time
  /// would often be wrong.
  Widget _transactionRow(Transactions t, double amount) {
    final text = ShadTheme.of(context).textTheme;
    final type = t.paytype.trim();
    final title = type.isEmpty
        ? 'Payment'
        : '${type[0].toUpperCase()}${type.substring(1).toLowerCase()} payment';
    final details = [
      if (t.ornum.trim().isNotEmpty) 'OR ${t.ornum.trim()}',
      Fmt.date(t.transdate),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.p.copyWith(fontWeight: FontWeight.w600)),
                Gap.hXs,
                Text(details, style: text.muted, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Gap.wSm,
          Text(Fmt.money(amount), style: text.p.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
