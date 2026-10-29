import 'package:flutter/material.dart';
import 'package:contained_tab_bar_view/contained_tab_bar_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pushtrial/models/enrolled_stud.dart';
import 'package:pushtrial/api/api.dart';
import 'dart:convert';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/models/user_data.dart';
import 'package:pushtrial/models/schedule.dart';
import 'package:pushtrial/models/event.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';
import 'package:pushtrial/models/school_info.dart';

class TabCard extends StatefulWidget {
  const TabCard({super.key});

  @override
  State<TabCard> createState() => TabCardState();
}

class TabCardState extends State<TabCard> {
  User user = UserData.myUser;
  String id = '0';
  String? sid;
  int syid = 1;
  int semid = 1;
  int sectionid = 0;
  int levelid = 0;
  String selectedYear = '';

  String selectedMonth = '';
  String selectedSem = '';
  List<String> semesters = [];
  List<String> months = [];
  List<String> years = [];
  List<SchedData> listOfSched = [];
  List<SchedItem> listOfItem2 = [];
  List<SchedItem> listOfItem3 = [];
  late List<Appointment> _appointments = [];
  List<EnrolledStud> enrolledstud = [];
  List<Event> events = [];

  String syDesc = '';
  String sem = '';

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
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: const EdgeInsets.only(left: 30, right: 30),
      child: Container(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.4),
        child: ContainedTabBarView(
          tabs: [
            _buildTab(Icons.library_books, "Enrollment"),
            _buildTab(Icons.class_, "Today's Class"),
            _buildTab(Icons.calendar_today, "Events"),
          ],
          views: [
            _buildTabContentEnrollment(),
            _buildTabContentClass(),
            _buildTabContentCalendar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(IconData icon, String title) {
    return Column(
      children: [
        Icon(icon, color: schoolColor),
        const SizedBox(height: 4.0),
        Text(title, style: TextStyle(fontSize: 11, color: schoolColor)),
      ],
    );
  }

  Widget _buildTabContentEnrollment() {
    if (enrolledstud.isEmpty) {
      return Center(
        child: Text(
          "Loading...Please check internet connection",
          style: TextStyle(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
    }

    final latestInfo = enrolledstud.lastWhere(
      (element) => element.sydesc == selectedYear,
    );

    final courseText = latestInfo.courseDesc.isNotEmpty
        ? latestInfo.courseDesc
        : '';

    final strandText = latestInfo.strandname.isNotEmpty
        ? latestInfo.strandname
        : '';

    final yearText = latestInfo.sydesc.isNotEmpty ? latestInfo.sydesc : '';

    final semText = latestInfo.semester.isNotEmpty ? latestInfo.semester : '';

    final sectionText = latestInfo.sectionname.isNotEmpty
        ? latestInfo.sectionname
        : '';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(
          left: 30.0,
          right: 30.0,
          top: 20.0,
          bottom: 20.0,
        ),
        child: Card(
          elevation: 5.0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
            side: BorderSide(color: schoolColor, width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  children: [
                    const Center(
                      child: Text(
                        'Enrollment Information',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    if (yearText.isNotEmpty && semText.isNotEmpty)
                      Center(
                        child: Text(
                          '$yearText - $semText',
                          style: const TextStyle(
                            fontSize: 12.0,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    if (yearText.isNotEmpty && semText.isEmpty)
                      Center(
                        child: Text(
                          yearText,
                          style: const TextStyle(
                            fontSize: 12.0,
                            color: Colors.black,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10.0),
                Row(
                  children: [
                    const Icon(
                      Icons.confirmation_number,
                      color: Colors.black,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        sid!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    const Icon(
                      Icons.description,
                      color: Colors.black,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        latestInfo.levelname,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (strandText.isNotEmpty && latestInfo.levelid < 17) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.assessment,
                        color: Colors.black,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          strandText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (courseText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.assessment,
                        color: Colors.black,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          courseText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (sectionText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.assessment,
                        color: Colors.black,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          sectionText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContentClass() {
    if (listOfItem3.isEmpty) {
      return const Center(
        child: Text(
          "No classes scheduled for today.",
          style: TextStyle(fontSize: 12, color: Colors.black),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: ListView.builder(
        itemCount: listOfItem3.length,
        itemBuilder: (context, index) {
          final schedItem = listOfItem3.elementAt(index);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Card(
              color: schoolColor,
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10.0),
                    width: 70,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            schedItem.room,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: schoolColor, width: 0.5),
                          right: BorderSide(color: schoolColor, width: 0.5),
                          bottom: BorderSide(color: schoolColor, width: 0.5),
                          left: BorderSide.none,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(0.0),
                          topRight: Radius.circular(8.0),
                          bottomRight: Radius.circular(8.0),
                          bottomLeft: Radius.circular(0.0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            schedItem.subject,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 200,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person,
                                  color: Colors.black,
                                  size: 16,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    schedItem.teacher,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: Colors.black,
                                size: 16,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "${schedItem.start} - ${schedItem.end}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabContentCalendar() {
    if (events.isEmpty) {
      return const Center(
        child: Text(
          "No events scheduled for today.",
          style: TextStyle(fontSize: 12, color: Colors.black),
        ),
      );
    }

    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    List<Event> todayEvents = events.where((event) {
      return (event.startTime.isBefore(endOfDay) &&
          event.endTime.isAfter(startOfDay));
    }).toList();

    if (todayEvents.isEmpty) {
      return const Center(
        child: Text(
          "No events scheduled for today.",
          style: TextStyle(fontSize: 12, color: Colors.black),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: ListView.builder(
        itemCount: todayEvents.length,
        itemBuilder: (context, index) {
          Event event = todayEvents[index];
          String formattedDate = DateFormat(
            'MMMM d, yyyy',
          ).format(event.startTime);
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: schoolColor),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 5.0),
                  if (event.venue.isNotEmpty)
                    Text(
                      event.venue,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12.0,
                      ),
                    ),
                  const SizedBox(height: 5.0),
                  Text(
                    formattedDate,
                    style: const TextStyle(color: Colors.black, fontSize: 12.0),
                  ),
                  const SizedBox(height: 5.0),
                  Text(
                    event.time,
                    style: const TextStyle(color: Colors.black, fontSize: 12.0),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> getUserInfo() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final json = preferences.getString('studid');

    if (json != null) {
      setState(() {
        id = json;
      });
      await getEnrolledStud();
    }
    setState(() {});
  }

  getUser() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final json = preferences.getString('user');
    setState(() {});
    user = json == null ? UserData.myUser : User.fromJson(jsonDecode(json));

    sid = user.sid;
    await getEnrolledStud();
    await getStudSchedule;
    await getSchedByMonth();
    {
      setState(() {});
    }
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

  String getCurrentDay() {
    DateTime now = DateTime.now();
    List<String> daysOfWeek = [
      'sunday',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
    ];
    return daysOfWeek[now.weekday % 7];
  }

  getSchedByMonth() {
    Set<String> uniqueSet = months.toSet();
    months = uniqueSet.toList();

    if (selectedMonth.isEmpty) {
      return null;
    } else {
      listOfItem3.clear();
      String currentDay = getCurrentDay();
      for (var element in listOfItem2) {
        if (element.month == currentDay) {
          if (!listOfItem3.any(
            (item) =>
                item.subject == element.subject &&
                item.start == element.start &&
                item.end == element.end,
          )) {
            setState(() {
              listOfItem3.add(
                SchedItem(
                  month: element.month,
                  start: element.start,
                  end: element.end,
                  subject: element.subject,
                  room: element.room,
                  teacher: element.teacher,
                ),
              );
            });
          }
        }
      }
    }
  }

  getStudSchedule(int index) async {
    months.clear();
    selectedMonth = '';
    listOfItem2.clear();
    List<SchedItem> listOfItem = [];

    try {
      final response = await CallApi().getSchedule(
        user.id,
        syid,
        index,
        sectionid,
        levelid,
      );
      Iterable list = json.decode(response.body);

      setState(() {
        listOfSched.clear();

        for (var element in list) {
          var ll = element['schedule'] ?? [];

          for (var el in ll) {
            if (el['day'] != null && el['sched'] != null) {
              var sched = el['sched'];
              // print('Schedule for day ${el['day']}: $sched');

              if (sched.isNotEmpty) {
                for (var item in sched) {
                  var start = item['start'] ?? '';
                  var end = item['end'] ?? '';
                  var subject = item['subject'] ?? '';
                  var room = item['room'] ?? '';
                  var teacher = item['teacher'] ?? '';

                  listOfItem.add(
                    SchedItem(
                      month: el['day'],
                      start: start,
                      end: end,
                      subject: subject,
                      room: room,
                      teacher: teacher,
                    ),
                  );
                  listOfItem2.add(
                    SchedItem(
                      month: el['day'],
                      start: start,
                      end: end,
                      subject: subject,
                      room: room,
                      teacher: teacher,
                    ),
                  );
                }
                months.add(el['day']);
              }
              listOfSched.add(SchedData(day: el['day'], sched: listOfItem));
            }
          }

          semid = index;
          selectedMonth = listOfSched.isNotEmpty ? listOfSched[0].day : '';
          getSchedByMonth();
        }
      });
    } catch (e) {
      print('Error fetching schedule: $e');
    }
  }

  List<Appointment> _getAppointments() {
    return events.map((event) {
      return Appointment(
        startTime: event.startTime,
        endTime: event.endTime,
        subject: event.title,
        color: Colors.blue,
      );
    }).toList();
  }

  getEnrolledStud() async {
    await CallApi().getEnrolledStud(user.id).then((response) {
      setState(() {
        var decodedJson = json.decode(response.body);

        if (decodedJson is Map<String, dynamic>) {
          Iterable list = decodedJson['enrolledstud_info'];
          enrolledstud = list
              .map((model) => EnrolledStud.fromJson(model))
              .toList();

          if (enrolledstud.isNotEmpty) {
            var latestInfo = enrolledstud.last;
            syid = latestInfo.syid;
            semid = latestInfo.semid;
            sectionid = latestInfo.sectionid;
            levelid = latestInfo.levelid;

            selectedYear = latestInfo.sydesc;
            selectedSem = latestInfo.semester;

            getStudSchedule(semid);
            getEvents();
          } else {}
        }
      });
    });
  }

  getEvents() async {
    await CallApi().getEvents(syid).then((response) {
      setState(() {
        Iterable ll = jsonDecode(response.body);
        events = (ll as List<dynamic>).map((e) {
          return Event(
            id: e['id'] ?? 0,
            title: e['title'] ?? '',
            venue: e['venue'] ?? '',
            startTime: DateTime.parse(e['startTime']),
            endTime: DateTime.parse(e['endTime']),
            time: e['time'] ?? '',
          );
        }).toList();
        _appointments = _getAppointments();
      });
    });
  }
}

void main() {
  runApp(const MaterialApp(home: Scaffold(body: TabCard())));
}
