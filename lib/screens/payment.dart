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
  static const _tabTransactions = 'transactions';
  static const _tabUploaded = 'uploaded';
  final ShadTabsController<String> _tabs = ShadTabsController(value: _tabTransactions);

  User user = UserData.myUser;
  int syid = 0; // 0 means "All School Years"
  int semid = 1;
  int id = 0;
  String sid = '0';
  String amountpaid = '0.00';
  String selectedYear = '0'; // Default to "All"
  String selectedSem = '';
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

      setState(() {
        // Default to "All School Years" (syid = 0)
        selectedYear = '0';
        syid = 0;
      });

      print('School Year loaded with "All" selected by default');
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

      List<Transactions> allTransactions = list
          .map((model) => Transactions.fromJson(model))
          .toList();

      // Filter transactions by selected school year (syid)
      // If syid is 0, show all transactions
      List<Transactions> filteredTransactions = syid == 0
          ? allTransactions
          : allTransactions
              .where((transaction) => transaction.syid == syid)
              .toList();

      filteredTransactions.sort(
        (a, b) =>
            DateTime.parse(b.transdate).compareTo(DateTime.parse(a.transdate)),
      );

      setState(() {
        trans = filteredTransactions;

        print("User ID: $id");
        print("Selected syid: $syid");
        print("Filter: ${syid == 0 ? 'All School Years' : 'School Year ID: $syid'}");
        print("Total transactions: ${filteredTransactions.length}");
      });
    }
  }

  getOnlinePayments() async {
    final response = await CallApi().getOnlinePayments(sid);

    if (response.statusCode == 200) {
      if (response.body.isEmpty) {
        print('No data returned');
        return;
      }
      Iterable list = json.decode(response.body);

      List<Payments> allPayments = list.map((model) => Payments.fromJson(model)).toList();

      // Filter payments by selected school year (syid)
      // If syid is 0, show all payments
      List<Payments> filteredPayments = syid == 0
          ? allPayments
          : allPayments
              .where((payment) => payment.syid == syid)
              .toList();

      setState(() {
        payments = filteredPayments;
      });

      print("Selected syid: $syid");
      print("Filter: ${syid == 0 ? 'All School Years' : 'School Year ID: $syid'}");
      print("Total payments: ${filteredPayments.length}");
    }
  }

  String _yearLabel(String value) {
    if (value == '0') return 'All school years';
    return schoolYear
        .firstWhere((y) => y.id.toString() == value, orElse: () => schoolYear.first)
        .sydesc;
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
            placeholder: const Text('Select school year'),
            initialValue: selectedYear,
            options: [
              // "All School Years" option
              const ShadOption(value: '0', child: Text('All school years')),
              // Individual school years
              for (final option in schoolYear)
                ShadOption(value: option.id.toString(), child: Text(option.sydesc)),
            ],
            selectedOptionBuilder: (context, value) => Text(_yearLabel(value)),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedYear = value;
                  syid = int.parse(value);
                });
                print('Selected School Year: $selectedYear, syid: $syid');
                // Fetch transactions and online payments for the selected year
                getTransactions();
                getOnlinePayments();
              }
            },
          ),
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

    return [
      for (final transaction in trans)
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _leading(
                Icon(
                  transaction.paytype == 'CASH' ? LucideIcons.banknote : LucideIcons.creditCard,
                  size: IconSize.row,
                  color: theme.colorScheme.foreground,
                ),
              ),
              Gap.wMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) {
                        final date = DateTime.parse(transaction.transdate);
                        return Text('${Fmt.date(date)} · ${Fmt.time(date)}', style: text.muted);
                      },
                    ),
                    Gap.hXs,
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${transaction.paytype} - OR#: ${transaction.ornum}',
                            style: text.small.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Gap.wSm,
                        Text(
                          Fmt.money(double.parse(transaction.amountpaid)),
                          style: text.p.copyWith(fontWeight: FontWeight.w600),
                        ),
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
}
