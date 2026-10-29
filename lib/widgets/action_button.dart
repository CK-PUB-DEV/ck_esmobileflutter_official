import 'package:pushtrial/api/api_version.dart';
import 'package:flutter/material.dart';
import '../screens/billing_information.dart';
import '../screens/billing_information_v2.dart';
import '../screens/reportcard.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/models/user_data.dart';
import 'package:pushtrial/api/api.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../screens/class_schedule.dart';
import '../screens/class_schedule_college.dart';
import '../screens/class_schedule_seniorhigh.dart';

import '../screens/school_calendar.dart';
import 'dart:convert';
import 'package:pushtrial/models/school_info.dart';
import 'package:pushtrial/models/enrolled_stud.dart';

class ActionButtons extends StatefulWidget {
  const ActionButtons({super.key});

  @override
  State<ActionButtons> createState() => ActionButtonsState();
}

class ActionButtonsState extends State<ActionButtons> {
  User user = UserData.myUser;
  String id = '0';
  String selectedSem = '';
  List<String> semesters = [];
  int syid = 0;
  int sectionid = 0;
  String sectionname = '';
  int levelid = 0;
  int semid = 0;
  String syDesc = '';
  String sem = '';
  String? selectedDay = '';
  String selectedMonth = '';
  String selectedYear = '';
  List<String> months = [];
  List<String> years = [];

  bool loading = true;
  String schoolVersion = 'v1';
  List<EnrolledStud> enrolledstud = [];
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
    getUser();
    getUserInfo();
    getSchoolInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        height: 100,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ActionButton(
              color: schoolColor,
              icon: Icons.calendar_month,
              label: 'Class\nSchedule',

              // onPressed: () {
              //   EnrolledStud? latestInfo = getSelectedEnrolledStud();
              //   if (latestInfo != null) {
              //     if (latestInfo.levelid >= 17) {
              //       Navigator.push(
              //         context,
              //         MaterialPageRoute(
              //             builder: (context) =>
              //                 const ClassScheduleCollegeScreen()),
              //       );
              //     } else if (latestInfo.levelid == 14 ||
              //         latestInfo.levelid == 15) {
              //       Navigator.push(
              //         context,
              //         MaterialPageRoute(
              //             builder: (context) =>
              //                 const ClassScheduleSeniorHighScreen()),
              //       );
              //     } else {
              //       Navigator.push(
              //         context,
              //         MaterialPageRoute(
              //             builder: (context) => const ClassScheduleScreen()),
              //       );
              //     }
              //   }
              // },
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ClassScheduleScreen(),
                  ),
                );
              },
            ),
            ActionButton(
              icon: Icons.folder_open,
              label: 'Report\nCard',
              color: schoolColor,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReportCardScreen(),
                  ),
                );
              },
            ),
            ActionButton(
              icon: Icons.calendar_month,
              label: 'School\nCalendar',
              color: schoolColor,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SchoolCalendar(),
                  ),
                );
              },
            ),
            ActionButton(
              icon: Icons.receipt_long,
              label: 'Billing\nInformation',
              color: schoolColor,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => schoolVersion == 'v2'
                        ? const BillingInformationV2Page()
                        : const BillingInformationPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  EnrolledStud? getSelectedEnrolledStud() {
    if (selectedYear.isEmpty) return null;

    return enrolledstud.firstWhere(
      (enrollment) => enrollment.sydesc.contains(selectedYear),
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
  }

  Future<void> getUser() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final json = preferences.getString('studid');
    final version = await ApiVersion.billingVersion();

    setState(() {
      schoolVersion = version;
    });

    if (json != null) {
      setState(() {
        id = json;
        loading = true;
      });
      await getEnrolledStud();
    }
    setState(() {
      loading = false;
    });
  }

  Future<void> getUserInfo() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final json = preferences.getString('user');

    setState(() {
      user = json == null ? UserData.myUser : User.fromJson(jsonDecode(json));
    });
  }

  getEnrolledStud() async {
    final response = await CallApi().getEnrolledStud(id);
    setState(() {
      var decodedJson = json.decode(response.body);

      if (decodedJson is Map<String, dynamic>) {
        Iterable list = decodedJson['enrolledstud_info'];
        enrolledstud = list
            .map((model) => EnrolledStud.fromJson(model))
            .toList();

        if (enrolledstud.isNotEmpty) {
          selectedYear = enrolledstud.last.sydesc;
          syDesc = selectedYear;

          var latestInfo = enrolledstud.firstWhere(
            (element) => element.sydesc == selectedYear,
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
          sem = latestInfo.semester;
        }
      }
    });
  }
}

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.outlined(
            onPressed: onPressed,
            icon: Icon(icon, color: color),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 68,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
