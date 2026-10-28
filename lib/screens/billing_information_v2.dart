import 'dart:convert';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:pushtrial/api/api.dart';
import 'package:pushtrial/models/ledger_v2.dart';
import 'package:pushtrial/models/school_info.dart';
import 'package:pushtrial/models/year_sem.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BillingInformationV2Page extends StatefulWidget {
  const BillingInformationV2Page({super.key});

  @override
  State<BillingInformationV2Page> createState() =>
      _BillingInformationV2PageState();
}

class _BillingInformationV2PageState extends State<BillingInformationV2Page>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  V2LedgerResponse? ledger;
  Color schoolColor = const Color.fromARGB(255, 14, 19, 29);

  String studid = '0';
  int syid = 1;
  int semid = 1;
  String selectedYear = '';
  String selectedSem = '';
  List<SchoolYear> schoolYear = [];
  List<Sem> schoolSem = [];

  late TabController _tabController;

  // Monthly tab: which month groups are expanded (by label), set up once per loaded ledger.
  static const _paidSectionKey = '__paid__';
  final Set<String> _openMonths = {};
  bool _monthsInitialized = false;

  @override
  void initState() {
    super.initState();
    if (!kDebugMode) ScreenProtector.preventScreenshotOn(); // debug builds stay capturable for testing
    _tabController = TabController(length: 2, vsync: this);
    _init();
  }

  @override
  void dispose() {
    ScreenProtector.preventScreenshotOff();
    _tabController.dispose();
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title ?? 'Error'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  String _formatAmount(double amount) =>
      'Php ${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'BILLING INFORMATION',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: schoolColor),
        ),
        centerTitle: true,
        bottom: loading || ledger == null
            ? null
            : TabBar(
                controller: _tabController,
                labelColor: schoolColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: schoolColor,
                tabs: const [
                  Tab(text: 'By Category'),
                  Tab(text: 'Monthly'),
                ],
              ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ledger == null
              ? const Center(child: Text('No data available.'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildYearSemSelector(),
        _buildSummaryCard(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildByCategoryTab(),
              _buildMonthlyTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildYearSemSelector() {
    if (schoolYear.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        spacing: 8,
        children: [
          Flexible(
            child: DropdownButtonFormField2<String>(
              value: selectedYear.isNotEmpty ? selectedYear : null,
              items: schoolYear
                  .map((y) => DropdownMenuItem(
                        value: y.id.toString(),
                        child: Text(y.sydesc, style: const TextStyle(fontSize: 11)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  selectedYear = v;
                  syid = int.parse(v);
                });
                _loadLedger();
              },
              decoration: const InputDecoration(
                labelText: 'School Year',
                labelStyle: TextStyle(fontSize: 11),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
          if (schoolSem.isNotEmpty)
            Flexible(
              child: DropdownButtonFormField2<String>(
                value: selectedSem.isNotEmpty ? selectedSem : null,
                items: schoolSem
                    .map((s) => DropdownMenuItem(
                          value: s.id.toString(),
                          child: Text(s.semester, style: const TextStyle(fontSize: 11)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    selectedSem = v;
                    semid = int.parse(v);
                  });
                  _loadLedger();
                },
                decoration: const InputDecoration(
                  labelText: 'Semester',
                  labelStyle: TextStyle(fontSize: 11),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final l = ledger!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Container(
                color: const Color.fromARGB(255, 14, 19, 29),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.credit_card, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.studentInfo.fullname,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${l.studentInfo.levelname}  •  ${l.studentInfo.sectionName}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                          Text(
                            l.studentInfo.granteeDescription,
                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: schoolColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Balance', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            Text(
                              _formatAmount(l.grandTotalBalance),
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Total Paid', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            Text(
                              _formatAmount(l.grandTotalPaid),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Same split as View Account: Total Paid is cash; vouchers/discounts and any
                    // overpayment Finance hasn't applied yet are shown on their own.
                    if (l.grandTotalDiscount > 0 || l.grandTotalOverpayment > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          [
                            if (l.grandTotalDiscount > 0) 'Discount/Credit: ${_formatAmount(l.grandTotalDiscount)}',
                            if (l.grandTotalOverpayment > 0) 'Overpayment: ${_formatAmount(l.grandTotalOverpayment)}',
                          ].join('   •   '),
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildByCategoryTab() {
    // Edge-to-edge (Android 15+): the system navigation bar overlaps the bottom of the page, so
    // lists need that much extra bottom padding or their last item can't scroll clear of it.
    final fees = ledger!.schoolFees;
    if (fees.isEmpty) return const Center(child: Text('No fee data.'));
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 16 + MediaQuery.paddingOf(context).bottom),
      itemCount: fees.length,
      itemBuilder: (_, i) => _buildFeeCategoryTile(fees[i]),
    );
  }

  Widget _buildFeeCategoryTile(V2SchoolFee fee) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(fee.particulars, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Wrap(
          spacing: 8,
          runSpacing: 2,
          children: [
            _amountChip('Due', fee.totalBalance, Colors.red.shade700),
            _amountChip('Paid', fee.totalPaid, Colors.green.shade700),
            if (fee.totalDiscount > 0)
              _amountChip('Discount', fee.totalDiscount, Colors.blue.shade700),
            if (fee.overpayment > 0)
              _amountChip('Overpaid', fee.overpayment, Colors.orange.shade800),
          ],
        ),
        children: fee.items.map((item) => _buildMonthItem(item)).toList(),
      ),
    );
  }

  Widget _buildMonthItem(V2SchoolFeeItem item) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      dense: true,
      title: Text(item.particulars, style: const TextStyle(fontSize: 12)),
      trailing: Text(
        _formatAmount(item.balance),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: item.balance > 0 ? Colors.red.shade700 : Colors.green.shade700,
        ),
      ),
      children: [
        if (item.nestedItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 6),
            child: Text('No breakdown available.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          )
        else
          ...item.nestedItems.map((n) => _buildNestedItem(n)),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildNestedItem(V2NestedItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(item.particulars, style: const TextStyle(fontSize: 11, color: Colors.black87))),
          Text(_formatAmount(item.amount), style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              _formatAmount(item.balance),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                color: item.balance > 0 ? Colors.red.shade600 : Colors.green.shade600,
              ),
            ),
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

  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _shortDate(DateTime d) => '${_monthNames[d.month - 1]} ${d.day}';

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
    if (schedules.isEmpty) return const Center(child: Text('No monthly data.'));

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

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        _buildDueSummary(schedules, today),
        const SizedBox(height: 10),
        _monthlyHeaderRow(),
        const Divider(height: 1, thickness: 0.5),
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
        color: oneTime.isEmpty ? Colors.green.shade700 : Colors.orange.shade800,
        icon: oneTime.isEmpty ? Icons.check_circle_outline : Icons.info_outline,
        title: oneTime.isEmpty ? 'All scheduled payments are settled' : 'One-time charges: ${_formatAmount(oneTimeTotal)}',
        lines: const [],
      );
    }

    const maxLines = 3;
    return Column(
      children: [
        if (overdue.isNotEmpty)
          _summaryBox(
            color: Colors.red.shade700,
            icon: Icons.error_outline,
            title: 'Overdue  ${_formatAmount(overdueTotal)}  •  ${overdue.length} payment${overdue.length == 1 ? '' : 's'}',
            lines: [
              for (final m in overdue.take(maxLines)) _SummaryLine('${_shortDate(m.dueOn!)}  ${_scheduleFees(m)}', m.balance),
              if (overdue.length > maxLines) _SummaryLine('+ ${overdue.length - maxLines} more, see the months below', null),
            ],
          ),
        if (overdue.isNotEmpty && upcoming.isNotEmpty) const SizedBox(height: 8),
        if (upcoming.isNotEmpty)
          _summaryBox(
            color: schoolColor,
            icon: Icons.event_outlined,
            title: 'Next due  ${_shortDate(upcoming.first.dueOn!)}',
            lines: [
              for (final m in upcoming.where((m) => m.dueOn == upcoming.first.dueOn))
                _SummaryLine(_scheduleFees(m), m.balance),
            ],
          ),
      ],
    );
  }

  Widget _summaryBox({
    required Color color,
    required IconData icon,
    required String title,
    required List<_SummaryLine> lines,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(line.text, style: const TextStyle(fontSize: 11))),
                  if (line.amount != null) ...[
                    const SizedBox(width: 8),
                    Text(_formatAmount(line.amount!), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _monthlyHeaderRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 22),
          const Expanded(child: Text('Month', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          _monthlyHeaderCell('Due'),
          _monthlyHeaderCell('Paid'),
          _monthlyHeaderCell('Disc/ Credit'),
          _monthlyHeaderCell('Balance'),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color, width: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMonthGroup(_MonthGroup g, DateTime today) {
    final open = _openMonths.contains(g.label);
    final overdue = g.schedules.any((m) => _isOverdue(m, today));
    final paid = g.balance <= 0.004;
    final chipColor = paid
        ? Colors.green.shade700
        : overdue
            ? Colors.red.shade700
            : Colors.orange.shade700;
    final chipLabel = paid
        ? 'PAID'
        : overdue
            ? 'OVERDUE'
            : 'PENDING';

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() {
            if (!_openMonths.remove(g.label)) _openMonths.add(g.label);
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Icon(open ? Icons.expand_more : Icons.chevron_right, size: 18, color: Colors.grey.shade600),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      _statusChip(chipLabel, chipColor),
                    ],
                  ),
                ),
                _monthlyAmountCell(g.due),
                _monthlyAmountCell(g.paid),
                _monthlyAmountCell(g.discount, color: g.discount > 0 ? Colors.blue.shade700 : null),
                _monthlyAmountCell(
                  g.balance,
                  bold: true,
                  color: paid ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ],
            ),
          ),
        ),
        if (open) ...g.schedules.map((m) => _buildScheduleRow(m, today)),
        const Divider(height: 1, thickness: 0.3),
      ],
    );
  }

  Widget _buildScheduleRow(V2MonthlyAssessment m, DateTime today) {
    final due = m.dueOn;
    final overdue = _isOverdue(m, today);
    return Container(
      color: Colors.grey.withValues(alpha: 0.06),
      padding: const EdgeInsets.only(left: 22, top: 6, bottom: 6),
      // The fee names get the full width on their own line: beside four amount columns they were
      // squeezed into a few characters and broke mid-word.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: _scheduleFees(m),
              children: [
                if (overdue)
                  TextSpan(text: '  •  overdue', style: TextStyle(color: Colors.red.shade700)),
              ],
            ),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  due == null ? 'No due date' : 'Due ${_shortDate(due)}',
                  style: TextStyle(fontSize: 10, color: overdue ? Colors.red.shade700 : Colors.grey),
                ),
              ),
              _monthlyAmountCell(m.totalDue),
              _monthlyAmountCell(m.totalPaid),
              _monthlyAmountCell(m.totalDiscount, color: m.totalDiscount > 0 ? Colors.blue.shade700 : null),
              _monthlyAmountCell(
                m.balance,
                bold: true,
                color: m.balance > 0.004 ? Colors.red.shade700 : Colors.green.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaidSection(List<_MonthGroup> paid, DateTime today) {
    final open = _openMonths.contains(_paidSectionKey);
    final first = paid.first.label;
    final last = paid.last.label;
    final range = paid.length == 1 ? first : '$first – $last';
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() {
            if (!_openMonths.remove(_paidSectionKey)) _openMonths.add(_paidSectionKey);
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Icon(open ? Icons.expand_more : Icons.chevron_right, size: 18, color: Colors.grey.shade600),
                ),
                Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Fully paid: $range (${paid.length} month${paid.length == 1 ? '' : 's'})',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade800),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (open) ...paid.map((g) => _buildMonthGroup(g, today)),
        const Divider(height: 1, thickness: 0.3),
      ],
    );
  }

  // The Monthly tab is table-like: four amount columns share the width, so amounts are shown
  // without the "Php" prefix (the header makes the unit clear) and scale down rather than wrap.
  static const double _monthlyColWidth = 56;

  Widget _monthlyHeaderCell(String label) {
    return SizedBox(
      width: _monthlyColWidth,
      child: Text(
        label,
        textAlign: TextAlign.right,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _monthlyAmountCell(double amount, {bool bold = false, Color? color}) {
    return SizedBox(
      width: _monthlyColWidth,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          _formatAmount(amount).replaceFirst('Php ', ''),
          style: TextStyle(
            fontSize: 11,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _amountChip(String label, double value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        Text(_formatAmount(value), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
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
