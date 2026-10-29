import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:pushtrial/api/api.dart';
import 'package:pushtrial/models/ledger_v2.dart';
import 'package:pushtrial/models/school_info.dart';
import 'package:pushtrial/models/year_sem.dart';
import 'package:pushtrial/widgets/ui/ui.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BillingInformationV2Page extends StatefulWidget {
  const BillingInformationV2Page({super.key});

  @override
  State<BillingInformationV2Page> createState() =>
      _BillingInformationV2PageState();
}

class _BillingInformationV2PageState extends State<BillingInformationV2Page> {

  // Slow responses can finish after the screen was closed; skip the update then.
  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }
  bool loading = true;
  V2LedgerResponse? ledger;
  Color schoolColor = const Color.fromARGB(255, 14, 19, 29);

  // Shown inline when there is no ledger to display (maintenance / failed load).
  String _errorTitle = 'Something went wrong';
  String _errorMessage = 'Check your connection and try again.';

  String studid = '0';
  int syid = 1;
  int semid = 1;
  String selectedYear = '';
  String selectedSem = '';
  List<SchoolYear> schoolYear = [];
  List<Sem> schoolSem = [];

  static const _tabCategory = 'category';
  static const _tabMonthly = 'monthly';
  final ShadTabsController<String> _tabs = ShadTabsController(value: _tabCategory);

  // Monthly tab: which month groups are expanded (by label), set up once per loaded ledger.
  static const _paidSectionKey = '__paid__';
  final Set<String> _openMonths = {};
  bool _monthsInitialized = false;

  @override
  void initState() {
    super.initState();
    if (!kDebugMode) ScreenProtector.preventScreenshotOn(); // debug builds stay capturable for testing
    _init();
  }

  @override
  void dispose() {
    ScreenProtector.preventScreenshotOff();
    _tabs.dispose();
    super.dispose();
  }

  Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 7 || hexString.length == 9) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    studid = prefs.getString('studid') ?? '0';
    await _loadSchoolInfo();
    await _loadYearAndSem();
  }

  Future<void> _loadSchoolInfo() async {
    try {
      final response = await CallApi().getSchoolInfo();
      final parsed = json.decode(response.body);
      if (parsed is List && parsed.isNotEmpty) {
        final info = SchoolInfo.fromJson(parsed[0]);
        setState(() {
          schoolColor = hexToColor(info.schoolcolor);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadYearAndSem() async {
    try {
      final response = await CallApi().getYearandSem();
      final data = json.decode(response.body) as Map<String, dynamic>;

      schoolYear = (data['sy'] as List)
          .map((e) => SchoolYear.fromJson(e))
          .toList()
        ..sort((a, b) => a.sydesc.compareTo(b.sydesc));
      schoolSem = (data['semester'] as List)
          .map((e) => Sem.fromJson(e))
          .toList();

      SchoolYear? activeYear;
      Sem? activeSem;
      try { activeYear = schoolYear.firstWhere((y) => y.isactive == 1); } catch (_) {}
      try { activeSem = schoolSem.firstWhere((s) => s.isactive == 1); } catch (_) {}

      selectedYear = (activeYear ?? (schoolYear.isNotEmpty ? schoolYear.last : null))?.id.toString() ?? '';
      selectedSem = (activeSem ?? (schoolSem.isNotEmpty ? schoolSem.first : null))?.id.toString() ?? '';

      if (selectedYear.isNotEmpty) syid = int.parse(selectedYear);
      if (selectedSem.isNotEmpty) semid = int.parse(selectedSem);
    } catch (_) {}

    await _loadLedger();
  }

  Future<void> _loadLedger() async {
    _openMonths.clear();
    _monthsInitialized = false;
    setState(() => loading = true);
    try {
      final response = await CallApi().getV2StudLedger(studid, syid, semid);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        setState(() {
          ledger = V2LedgerResponse.fromJson(data);
          loading = false;
        });
      } else {
        setState(() => loading = false);
        // _showError('Server returned status ${response.statusCode}.');
        _showError('Maintenance', 'This page is under maintenance. Please try again later.');
      }
    } catch (e) {
      setState(() => loading = false);
      _showError('Error', 'Failed to load billing data: $e');
    }
  }

  void _showError(String? title, String message) {
    if (!mounted) return;
    _errorTitle = title ?? 'Error';
    _errorMessage = message;
    // With no ledger on screen the error is shown inline (with Retry); with an older ledger
    // still showing, tell the user the refresh failed.
    if (ledger == null) {
      setState(() {});
      return;
    }
    ShadToaster.of(context).show(
      ShadToast.destructive(title: Text(_errorTitle), description: Text(_errorMessage)),
    );
  }

  // ---------------------------------------------------------------------------
  // Shell
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const AppPage(title: 'Billing information', body: LoadingSkeleton());
    }
    return AppPage(
      title: 'Billing information',
      children: [
        _buildYearSemSelector(),
        if (ledger == null)
          ErrorState(title: _errorTitle, message: _errorMessage, onRetry: _loadLedger)
        else ...[
          _buildSummaryCard(),
          _buildTabs(),
        ],
      ],
    );
  }

  Widget _buildTabs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadTabs<String>(
          controller: _tabs,
          tabs: const [
            ShadTab(value: _tabCategory, child: Text('By category')),
            ShadTab(value: _tabMonthly, child: Text('Monthly')),
          ],
        ),
        Gap.hMd,
        ListenableBuilder(
          listenable: _tabs,
          builder: (context, _) =>
              _tabs.selected == _tabMonthly ? _buildMonthlyTab() : _buildByCategoryTab(),
        ),
      ],
    );
  }

  Widget _buildYearSemSelector() {
    if (schoolYear.isEmpty) return const SizedBox.shrink();
    String yearLabel(String id) =>
        schoolYear.firstWhere((y) => y.id.toString() == id, orElse: () => schoolYear.first).sydesc;
    String semLabel(String id) =>
        schoolSem.firstWhere((s) => s.id.toString() == id, orElse: () => schoolSem.first).semester;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        children: [
          Expanded(
            child: ShadSelect<String>(
              placeholder: const Text('School year'),
              initialValue: selectedYear.isNotEmpty ? selectedYear : null,
              options: [
                for (final y in schoolYear)
                  ShadOption(value: y.id.toString(), child: Text(y.sydesc)),
              ],
              selectedOptionBuilder: (context, value) => Text(yearLabel(value)),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  selectedYear = v;
                  syid = int.parse(v);
                });
                _loadLedger();
              },
            ),
          ),
          if (schoolSem.isNotEmpty) ...[
            Gap.wSm,
            Expanded(
              child: ShadSelect<String>(
                placeholder: const Text('Semester'),
                initialValue: selectedSem.isNotEmpty ? selectedSem : null,
                options: [
                  for (final s in schoolSem)
                    ShadOption(value: s.id.toString(), child: Text(s.semester)),
                ],
                selectedOptionBuilder: (context, value) => Text(semLabel(value)),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    selectedSem = v;
                    semid = int.parse(v);
                  });
                  _loadLedger();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final l = ledger!;
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;
    final info = l.studentInfo;
    return AppCard(
      margin: const EdgeInsets.only(bottom: Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.userRound, size: IconSize.row, color: theme.colorScheme.mutedForeground),
              Gap.wSm,
              Expanded(
                child: Text(info.fullname, style: text.large, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          Gap.hXs,
          Text('${info.levelname}  •  ${info.sectionName}', style: text.muted),
          if (info.granteeDescription.trim().isNotEmpty) Text(info.granteeDescription, style: text.muted),
          Gap.hLg,
          Divider(height: 1, color: theme.colorScheme.border),
          Gap.hLg,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StatTile(
                  label: 'Total balance',
                  value: Fmt.money(l.grandTotalBalance),
                  icon: LucideIcons.wallet,
                  tone: l.grandTotalBalance > 0 ? theme.colorScheme.destructive : null,
                ),
              ),
              Gap.wLg,
              Expanded(
                child: StatTile(
                  label: 'Total paid',
                  value: Fmt.money(l.grandTotalPaid),
                  icon: LucideIcons.banknote,
                ),
              ),
            ],
          ),
          // Same split as View Account: Total Paid is cash; vouchers/discounts and any
          // overpayment Finance hasn't applied yet are shown on their own.
          if (l.grandTotalDiscount > 0 || l.grandTotalOverpayment > 0) ...[
            Gap.hMd,
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.xs,
              children: [
                if (l.grandTotalDiscount > 0)
                  StatusBadge('Discount/credit ${Fmt.money(l.grandTotalDiscount)}', status: AppStatus.info),
                if (l.grandTotalOverpayment > 0)
                  StatusBadge('Overpayment ${Fmt.money(l.grandTotalOverpayment)}', status: AppStatus.warning),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // By category tab
  // ---------------------------------------------------------------------------

  Widget _buildByCategoryTab() {
    final fees = ledger!.schoolFees;
    if (fees.isEmpty) {
      return const EmptyState(title: 'No fee data', message: 'Fees will appear here once assessed.');
    }
    return Column(children: [for (final fee in fees) _buildFeeCategoryTile(fee)]);
  }

  Widget _buildFeeCategoryTile(V2SchoolFee fee) {
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        // Hide ExpansionTile's own divider lines; the card border is enough.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.xs),
          childrenPadding: const EdgeInsets.only(bottom: Gap.sm),
          title: Text(fee.particulars, style: text.p.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: Gap.xs),
            child: Wrap(
              spacing: Gap.md,
              runSpacing: Gap.xs,
              children: [
                _labelValue('Due', Fmt.money(fee.totalBalance),
                    color: fee.totalBalance > 0 ? theme.colorScheme.destructive : null),
                _labelValue('Paid', Fmt.money(fee.totalPaid)),
                if (fee.totalDiscount > 0) _labelValue('Discount', Fmt.money(fee.totalDiscount)),
                if (fee.overpayment > 0) _labelValue('Overpaid', Fmt.money(fee.overpayment)),
              ],
            ),
          ),
          children: fee.items.map((item) => _buildMonthItem(item)).toList(),
        ),
      ),
    );
  }

  Widget _buildMonthItem(V2SchoolFeeItem item) {
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        dense: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: Gap.xl),
        title: Text(item.particulars, style: text.small),
        trailing: Text(
          Fmt.money(item.balance),
          style: text.small.copyWith(
            fontWeight: FontWeight.w600,
            color: item.balance > 0 ? theme.colorScheme.destructive : theme.colorScheme.foreground,
          ),
        ),
        children: [
          if (item.nestedItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.xl + Gap.sm, vertical: Gap.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('No breakdown available.', style: text.muted),
              ),
            )
          else
            ...item.nestedItems.map((n) => _buildNestedItem(n)),
        ],
      ),
    );
  }

  Widget _buildNestedItem(V2NestedItem item) {
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xl + Gap.sm, vertical: Gap.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(item.particulars, style: text.small)),
          Gap.wMd,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.money(item.amount), style: text.small),
              Text(
                'Bal ${Fmt.money(item.balance)}',
                style: text.muted.copyWith(
                  color: item.balance > 0 ? theme.colorScheme.destructive : theme.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Monthly tab
  //
  // The API returns one row per payment schedule due date, and every kind of fee has its own
  // schedule (Misc + Tuition on the 15th, Retreat on the 24th, Yearbook + Textbook on the 30th,
  // one-time adjustments with no date), so a month name can appear up to three times. Showing
  // those rows as-is reads like duplicates, so this tab:
  //   1. opens with what the student needs to know: overdue payments and the next one due;
  //   2. lists the months that still have a balance, each expandable into its schedules
  //      (date + the fees on it);
  //   3. tucks the fully paid months into one collapsed section.
  // Every figure comes straight from the API rows; nothing is recalculated here.
  // ---------------------------------------------------------------------------

  // "TUITION FEE + MISCELLANEOUS" for a schedule row; falls back to the row's own label.
  String _scheduleFees(V2MonthlyAssessment m) {
    final names = <String>[];
    for (final fee in m.breakdown) {
      final name = fee.feeName.trim();
      if (name.isNotEmpty && !names.contains(name)) names.add(name);
    }
    return names.isEmpty ? m.assessmentLabel : names.join(' + ');
  }

  bool _isOverdue(V2MonthlyAssessment m, DateTime today) {
    final due = m.dueOn;
    return m.balance > 0.004 && due != null && due.isBefore(today);
  }

  List<_MonthGroup> _groupMonths(List<V2MonthlyAssessment> schedules) {
    final byLabel = <String, List<V2MonthlyAssessment>>{};
    for (final m in schedules) {
      final label = m.dueOn == null ? 'One-time charges' : m.assessmentLabel;
      byLabel.putIfAbsent(label, () => []).add(m);
    }
    final groups = byLabel.entries.map((e) => _MonthGroup(e.key, e.value)).toList();
    // Dated months in due-date order, one-time charges last.
    groups.sort((a, b) {
      if (a.firstDue == null && b.firstDue == null) return 0;
      if (a.firstDue == null) return 1;
      if (b.firstDue == null) return -1;
      return a.firstDue!.compareTo(b.firstDue!);
    });
    return groups;
  }

  Widget _buildMonthlyTab() {
    final schedules = ledger!.monthlyAssessments;
    if (schedules.isEmpty) {
      return const EmptyState(title: 'No monthly data', message: 'Payment schedules will appear here.');
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final groups = _groupMonths(schedules);
    final unpaid = groups.where((g) => g.balance > 0.004).toList();
    final paid = groups.where((g) => g.balance <= 0.004).toList();

    // Open the first month that still has a balance, once per loaded ledger.
    if (!_monthsInitialized) {
      _monthsInitialized = true;
      if (unpaid.isNotEmpty) _openMonths.add(unpaid.first.label);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDueSummary(schedules, today),
        for (final g in unpaid) _buildMonthGroup(g, today),
        if (paid.isNotEmpty) _buildPaidSection(paid, today),
      ],
    );
  }

  Widget _buildDueSummary(List<V2MonthlyAssessment> schedules, DateTime today) {
    int byDue(V2MonthlyAssessment a, V2MonthlyAssessment b) => a.dueOn!.compareTo(b.dueOn!);

    final overdue = schedules.where((m) => _isOverdue(m, today)).toList()..sort(byDue);
    final upcoming = schedules
        .where((m) => m.balance > 0.004 && m.dueOn != null && !_isOverdue(m, today))
        .toList()
      ..sort(byDue);
    final overdueTotal = overdue.fold<double>(0, (sum, m) => sum + m.balance);

    if (overdue.isEmpty && upcoming.isEmpty) {
      final oneTime = schedules.where((m) => m.dueOn == null && m.balance > 0.004).toList();
      final oneTimeTotal = oneTime.fold<double>(0, (sum, m) => sum + m.balance);
      return _summaryBox(
        tone: oneTime.isEmpty ? AppStatus.success : AppStatus.warning,
        icon: oneTime.isEmpty ? LucideIcons.circleCheck : LucideIcons.info,
        title: oneTime.isEmpty ? 'All scheduled payments are settled' : 'One-time charges: ${Fmt.money(oneTimeTotal)}',
        lines: const [],
      );
    }

    const maxLines = 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (overdue.isNotEmpty)
          _summaryBox(
            tone: AppStatus.danger,
            icon: LucideIcons.circleAlert,
            title: 'Overdue  ${Fmt.money(overdueTotal)}  •  ${overdue.length} payment${overdue.length == 1 ? '' : 's'}',
            lines: [
              for (final m in overdue.take(maxLines)) _SummaryLine('${Fmt.dayMonth(m.dueOn)}  ${_scheduleFees(m)}', m.balance),
              if (overdue.length > maxLines) _SummaryLine('+ ${overdue.length - maxLines} more, see the months below', null),
            ],
          ),
        if (upcoming.isNotEmpty)
          _summaryBox(
            tone: AppStatus.info,
            icon: LucideIcons.calendarClock,
            title: 'Next due  ${Fmt.dayMonth(upcoming.first.dueOn)}',
            lines: [
              for (final m in upcoming.where((m) => m.dueOn == upcoming.first.dueOn))
                _SummaryLine(_scheduleFees(m), m.balance),
            ],
          ),
      ],
    );
  }

  Widget _summaryBox({
    required AppStatus tone,
    required IconData icon,
    required String title,
    required List<_SummaryLine> lines,
  }) {
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;
    final accent = tone == AppStatus.danger ? theme.colorScheme.destructive : theme.colorScheme.foreground;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Container(
        width: double.infinity,
        padding: Gap.card,
        decoration: BoxDecoration(
          color: tone == AppStatus.danger
              ? theme.colorScheme.destructive.withValues(alpha: 0.08)
              : theme.colorScheme.card,
          border: Border.all(
            color: tone == AppStatus.danger
                ? theme.colorScheme.destructive.withValues(alpha: 0.5)
                : theme.colorScheme.border,
          ),
          borderRadius: theme.radius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: IconSize.row, color: accent),
                Gap.wSm,
                Expanded(
                  child: Text(title, style: text.p.copyWith(fontWeight: FontWeight.w600, color: accent)),
                ),
              ],
            ),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(top: Gap.sm, left: IconSize.row + Gap.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(line.text, style: text.small)),
                    if (line.amount != null) ...[
                      Gap.wSm,
                      Text(Fmt.money(line.amount), style: text.small.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthGroup(_MonthGroup g, DateTime today) {
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;
    final open = _openMonths.contains(g.label);
    final overdue = g.schedules.any((m) => _isOverdue(m, today));
    final paid = g.balance <= 0.004;
    final status = paid ? AppStatus.success : (overdue ? AppStatus.danger : AppStatus.warning);
    final statusLabel = paid ? 'Paid' : (overdue ? 'Overdue' : 'Pending');

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: theme.radius,
            onTap: () => setState(() {
              if (!_openMonths.remove(g.label)) _openMonths.add(g.label);
            }),
            child: Padding(
              padding: Gap.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        open ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                        size: IconSize.row,
                        color: theme.colorScheme.mutedForeground,
                      ),
                      Gap.wSm,
                      Expanded(
                        child: Text(g.label, style: text.p.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      StatusBadge(statusLabel, status: status),
                    ],
                  ),
                  Gap.hSm,
                  _figures(due: g.due, paid: g.paid, discount: g.discount, balance: g.balance),
                ],
              ),
            ),
          ),
          if (open) ...[
            Divider(height: 1, color: theme.colorScheme.border),
            for (final m in g.schedules) _buildScheduleRow(m, today),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleRow(V2MonthlyAssessment m, DateTime today) {
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;
    final due = m.dueOn;
    final overdue = _isOverdue(m, today);
    return Container(
      color: theme.colorScheme.muted.withValues(alpha: 0.4),
      padding: const EdgeInsets.fromLTRB(Gap.lg + IconSize.row + Gap.sm, Gap.md, Gap.lg, Gap.md),
      // The fee names get the full width on their own line so they never squeeze into a few
      // characters beside the amounts.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_scheduleFees(m), style: text.small.copyWith(fontWeight: FontWeight.w600)),
          Gap.hXs,
          Text(
            due == null ? 'No due date' : 'Due ${Fmt.dayMonth(due)}${overdue ? '  •  overdue' : ''}',
            style: text.muted.copyWith(color: overdue ? theme.colorScheme.destructive : null),
          ),
          Gap.hSm,
          _figures(due: m.totalDue, paid: m.totalPaid, discount: m.totalDiscount, balance: m.balance),
        ],
      ),
    );
  }

  Widget _buildPaidSection(List<_MonthGroup> paid, DateTime today) {
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;
    final open = _openMonths.contains(_paidSectionKey);
    final first = paid.first.label;
    final last = paid.last.label;
    final range = paid.length == 1 ? first : '$first – $last';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            borderRadius: theme.radius,
            onTap: () => setState(() {
              if (!_openMonths.remove(_paidSectionKey)) _openMonths.add(_paidSectionKey);
            }),
            child: Padding(
              padding: Gap.card,
              child: Row(
                children: [
                  Icon(
                    open ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                    size: IconSize.row,
                    color: theme.colorScheme.mutedForeground,
                  ),
                  Gap.wSm,
                  Icon(LucideIcons.circleCheck, size: IconSize.inline, color: theme.colorScheme.mutedForeground),
                  Gap.wSm,
                  Expanded(
                    child: Text(
                      'Fully paid: $range (${paid.length} month${paid.length == 1 ? '' : 's'})',
                      style: text.small.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (open) ...paid.map((g) => _buildMonthGroup(g, today)),
      ],
    );
  }

  // The four figures of a month or schedule, wrapped so they stack on narrow phones instead of
  // squeezing into columns: due, paid, discount/credit and balance.
  Widget _figures({
    required double due,
    required double paid,
    required double discount,
    required double balance,
  }) {
    final theme = ShadTheme.of(context);
    return Wrap(
      spacing: Gap.lg,
      runSpacing: Gap.xs,
      children: [
        _labelValue('Due', Fmt.money(due)),
        _labelValue('Paid', Fmt.money(paid)),
        _labelValue('Disc/credit', Fmt.money(discount)),
        _labelValue(
          'Balance',
          Fmt.money(balance),
          bold: true,
          color: balance > 0.004 ? theme.colorScheme.destructive : null,
        ),
      ],
    );
  }

  Widget _labelValue(String label, String value, {bool bold = false, Color? color}) {
    final text = ShadTheme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: text.muted),
        Text(
          value,
          style: text.small.copyWith(
            fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

// A month on the Monthly tab: all payment schedules that share a month name.
class _MonthGroup {
  final String label;
  final List<V2MonthlyAssessment> schedules;

  _MonthGroup(this.label, List<V2MonthlyAssessment> schedules)
      : schedules = (List<V2MonthlyAssessment>.of(schedules)
          ..sort((a, b) {
            final ad = a.dueOn;
            final bd = b.dueOn;
            if (ad == null || bd == null) return 0;
            return ad.compareTo(bd);
          }));

  double get due => schedules.fold(0, (sum, m) => sum + m.totalDue);
  double get paid => schedules.fold(0, (sum, m) => sum + m.totalPaid);
  double get discount => schedules.fold(0, (sum, m) => sum + m.totalDiscount);
  double get balance => schedules.fold(0, (sum, m) => sum + m.balance);

  DateTime? get firstDue => schedules.map((m) => m.dueOn).whereType<DateTime>().fold<DateTime?>(null, (min, d) => min == null || d.isBefore(min) ? d : min);
}

class _SummaryLine {
  final String text;
  final double? amount;
  const _SummaryLine(this.text, this.amount);
}
