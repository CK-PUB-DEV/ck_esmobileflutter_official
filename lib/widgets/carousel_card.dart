import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:pushtrial/api/api.dart';
import 'package:pushtrial/models/enrolled_stud.dart';
import 'package:pushtrial/models/ledger.dart';
import 'package:pushtrial/models/school_info.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/models/user_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CarouselCard extends StatefulWidget {
  const CarouselCard({super.key});

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
  String totalBalance = '₱ 0.00';
  // Shown instead of a misleading "₱ 0.00" while the balance loads or when it can't be loaded.
  bool _balanceLoading = true;
  String? _balanceError;

  List<Ledger> data = [];
  List<EnrolledStud> enrolledstud = [];
  List<SchoolInfo> schoolInfo = [];
  User user = UserData.myUser;
  // Dark until the school colour arrives: the card's text and spinner are white, so a white
  // default made the card look blank while loading.
  Color schoolColor = const Color(0xFF1D1D1D);

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  String _schoolVersion = 'v1';

  Future<void> _initializeData() async {
    await getUser();

    // School colour and enrollment don't depend on each other, so fetch them together;
    // the ledger needs syid/semid from enrollment and runs after.
    await Future.wait([
      _guard('school info', getSchoolInfo),
      _guard('enrollment', getEnrolledStud),
    ]);

    final prefs = await SharedPreferences.getInstance();
    _schoolVersion = prefs.getString('schoolVersion') ?? 'v1';

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

  // Prefer the server's own reason (e.g. "Student Ledger is currently unavailable.").
  String _serverMessage(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded['message'] is String) return decoded['message'];
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

  Future<void> getSchoolInfo() async {
    final response = await CallApi().getSchoolInfo();
    final parsed = json.decode(response.body);
    if (parsed is List && mounted) {
      setState(() {
        schoolInfo = parsed.map((e) => SchoolInfo.fromJson(e)).toList();
        schoolColor = hexToColor(schoolInfo[0].schoolcolor);
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
        print('EnrolledStud - id: $id, syid: $syid, semid: $semid, syDesc: $syDesc');
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
      _setBalance('₱ ${total.toStringAsFixed(2)}');
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
          .getStudLedger(id, syid, semid)
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
      print('Entry $i: particulars="${data[i].particulars}", balance="${data[i].balance}"');
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

    print('Final Total found: particulars="${total.particulars}", balance="${total.balance}"');

    _setBalance('₱ ${total.balance}');
  }

  Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 7 || hexString.length == 9) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Color darkenColor(Color color, [double amount = 0.15]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
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

    final courseText = latestInfo.courseDesc.isNotEmpty
        ? latestInfo.courseDesc
        : '';
    final strandText = latestInfo.strandname.isNotEmpty
        ? latestInfo.strandname
        : '';
    final sectionText = latestInfo.sectionname;
    final levelName = latestInfo.levelname;
    final sidText = sid ?? 'No SID';

    return Padding(
      padding: const EdgeInsets.only(bottom: 0.0),
      child: CarouselSlider(
        options: CarouselOptions(
          height: 175,
          autoPlay: true,
          autoPlayInterval: const Duration(seconds: 5),
          autoPlayAnimationDuration: const Duration(milliseconds: 800),
          enlargeCenterPage: true,
          aspectRatio: 16 / 9,
          viewportFraction: 0.8,
        ),
        items: [
          // Balance Card
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.0),
              gradient: LinearGradient(
                colors: [darkenColor(schoolColor), schoolColor],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Balance',
                    style: TextStyle(color: Colors.white, fontSize: 12.0),
                  ),
                  if (_balanceLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  else if (_balanceError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _balanceError!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    Text(
                      totalBalance,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 30,
                      ),
                    ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      "SY: $syDesc${sem.isNotEmpty ? "\nSem: $sem" : ""}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Enrollment Info Card
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.0),
              gradient: LinearGradient(
                colors: [darkenColor(schoolColor), schoolColor],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 20.0,
                top: 20.0,
                right: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Expanded(
                        child: Text(
                          'Enrollment Information',
                          style: TextStyle(color: Colors.white, fontSize: 12.0),
                        ),
                      ),
                      Icon(Icons.person, color: Colors.white),
                    ],
                  ),
                  Text(
                    sidText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (levelName.isNotEmpty)
                    Text(
                      levelName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.0,
                      ),
                    ),
                  if (courseText.isNotEmpty || strandText.isNotEmpty)
                    Text(
                      courseText.isNotEmpty ? courseText : strandText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.0,
                      ),
                    ),

                  Text(
                    sectionText,
                    style: const TextStyle(color: Colors.white, fontSize: 12.0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
