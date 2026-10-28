import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:pushtrial/models/year_sem.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushtrial/api/api.dart';
import 'package:pushtrial/models/ledger.dart';
import 'dart:convert';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:pushtrial/models/school_info.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'BILLING INFORMATION',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: schoolColor,
          ),
        ),
        centerTitle: true,
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(semanticsLabel: 'Loading...'),
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    spacing: 2.0,
                    children: [
                      Flexible(
                        flex: 1,
                        child: DropdownButtonFormField2<String>(
                          value: selectedYear.isNotEmpty ? selectedYear : null,
                          items: schoolYear
                              .map(
                                (option) => DropdownMenuItem(
                                  value: option.id.toString(),
                                  child: Text(
                                    option.sydesc,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedYear = value!;
                              syid = int.parse(selectedYear);
                            });
                            if (selectedSem.isNotEmpty) getLedger();
                          },
                          decoration: const InputDecoration(
                            labelText: 'School Year',
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      // const SizedBox(width: 10.0),
                     if (levelid == 14 || levelid == 15 || levelid >= 17) 
                        Flexible(
                          flex: 1,
                          child: DropdownButtonFormField2<String>(
                            value: selectedSem.isNotEmpty ? selectedSem : null,
                            items: schoolSem
                                .map(
                                  (option) => DropdownMenuItem(
                                    value: option.id.toString(),
                                    child: Text(
                                      option.semester,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedSem = value!;
                                semid = int.parse(selectedSem);
                              });
                              if (selectedYear.isNotEmpty) getLedger();
                            },
                            decoration: const InputDecoration(
                              labelText: 'Semester',
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Container(
                              color: const Color.fromARGB(255, 14, 19, 29),
                              child: Stack(
                                children: [
                                  const Positioned(
                                    top: 16,
                                    left: 16,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.credit_card,
                                          size: 30,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    top: 16,
                                    right: 16,
                                    child: selectedYear.isNotEmpty && selectedSem.isNotEmpty
                                        ? Text(
                                            "SY: ${schoolYear.isNotEmpty ? schoolYear.firstWhere((year) => year.id.toString() == selectedYear, orElse: () => schoolYear.first).sydesc : ''}"
                                            "${levelid > 13 && schoolSem.isNotEmpty ? "\nSem: ${schoolSem.firstWhere((sem) => sem.id.toString() == selectedSem, orElse: () => schoolSem.first).semester}" : ""}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  const Positioned(
                                    bottom: 16,
                                    left: 16,
                                    child: Text(
                                      "Total Balance",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Container(
                              color: schoolColor,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      totalBalance,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    color: const Color.fromARGB(255, 14, 19, 29),
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.money, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Payments',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            totalPayment,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (schoolInfo.isNotEmpty &&
                      schoolInfo[0].abbreviation.toUpperCase() == 'SBC') ...[
                    const SizedBox(height: 8),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 12, color: Colors.grey),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Non-tuition / walk-in cash payments may not be reflected in the total.',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Header row
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Particulars',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 76,
                        child: Text(
                          'Amount',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        width: 76,
                        child: Text(
                          'Payments',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const Divider(thickness: 0.5),
                  Expanded(
                    child: ListView.separated(
                      itemCount: data.length,
                      separatorBuilder: (_, __) =>
                          const Divider(thickness: 0.3, height: 1),
                      itemBuilder: (context, index) {
                        final ledger = data[index];
                        final isTotal =
                            ledger.particulars.startsWith('TOTAL:');
                        final textColor = ledger.isVoided
                            ? Colors.grey
                            : Colors.black;
                        final textDecoration = ledger.isVoided
                            ? TextDecoration.lineThrough
                            : TextDecoration.none;
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ledger.particulars,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 11,
                                        fontWeight: isTotal
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        decoration: textDecoration,
                                        decorationColor: Colors.grey,
                                      ),
                                    ),
                                    if (ledger.isVoided)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          border: Border.all(
                                              color: Colors.red, width: 0.8),
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                        child: const Text(
                                          'VOID',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 76,
                                child: Text(
                                  ledger.amount,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 11,
                                    fontWeight: isTotal
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    decoration: textDecoration,
                                    decorationColor: Colors.grey,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 76,
                                child: Text(
                                  ledger.payment,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 11,
                                    fontWeight: isTotal
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    decoration: textDecoration,
                                    decorationColor: Colors.grey,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
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
        
        // Show error dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Error'),
                content: Text(
                  'Failed to load billing information. The server returned an error (Status: ${response.statusCode}). Please try again later or contact support.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        }
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
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text(
                'An error occurred while loading billing information: ${e.toString()}. Please check your internet connection and try again.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    }
  }
}
