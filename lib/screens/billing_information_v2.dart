import 'dart:convert';
import 'package:dropdown_button2/dropdown_button2.dart';
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

  @override
  void initState() {
    super.initState();
    ScreenProtector.preventScreenshotOn();
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
                child: Row(
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildByCategoryTab() {
    final fees = ledger!.schoolFees;
    if (fees.isEmpty) return const Center(child: Text('No fee data.'));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
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
        subtitle: Row(
          children: [
            _amountChip('Due', fee.totalBalance, Colors.red.shade700),
            const SizedBox(width: 8),
            _amountChip('Paid', fee.totalPaid, Colors.green.shade700),
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

  Widget _buildMonthlyTab() {
    final months = ledger!.monthlyAssessments;
    if (months.isEmpty) return const Center(child: Text('No monthly data.'));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              const Expanded(child: Text('Month', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              SizedBox(width: 90, child: Text('Due', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
              const SizedBox(width: 8),
              SizedBox(width: 90, child: Text('Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: months.length,
            separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.3),
            itemBuilder: (_, i) => _buildMonthlyRow(months[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyRow(V2MonthlyAssessment m) {
    final isPending = m.status == 'pending';
    final statusColor = isPending ? Colors.orange.shade700 : Colors.green.shade700;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.assessmentLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                Text(m.dueDate, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    border: Border.all(color: statusColor, width: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    m.status.toUpperCase(),
                    style: TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(_formatAmount(m.totalDue), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              _formatAmount(m.balance),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: m.balance > 0 ? Colors.red.shade700 : Colors.green.shade700,
              ),
            ),
          ),
        ],
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
