import 'package:flutter/material.dart';
import 'package:pushtrial/widgets/ui/ui.dart';
import 'package:pushtrial/models/user_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/api/api.dart';
import 'package:pushtrial/models/enrolled_stud.dart';
import 'package:pushtrial/models/school_info.dart';
import 'package:pushtrial/models/schedule.dart';
import 'dart:convert';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pushtrial/models/year_sem.dart';

class ClassScheduleScreen extends StatefulWidget {
  const ClassScheduleScreen({super.key});

  @override
  State<ClassScheduleScreen> createState() => _ClassScheduleScreenState();
}

class _ClassScheduleScreenState extends State<ClassScheduleScreen> {

  // Slow responses can finish after the screen was closed; skip the update then.
  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }
  User user = UserData.myUser;
  String id = '0';
  List<String> semesters = [];
  int syid = 0;
  int sectionid = 0;
  String sectionname = '';
  int levelid = 0;
  int semid = 0;
  String? selectedDay = '';
  String selectedMonth = '';
  String selectedYear = '';
  String selectedSem = '';
  List<String> months = [];
  List<String> years = [];
  List<SchedData> listOfSched = [];
  List<SchedItem> listOfItem2 = [];

  List<EnrolledStud> enrolledstud = [];

  List<SchoolYear> schoolYear = [];
  List<Sem> schoolSem = [];
  bool loading = true;
  final DateFormat timeFormat = DateFormat.jm();
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

    final activeYear = schoolYear.firstWhere(
      (year) => year.isactive == 1,
      orElse: () => schoolYear.first,
    );
    final activeSem = schoolSem.firstWhere(
      (sem) => sem.isactive == 1,
      orElse: () => schoolSem.first,
    );

    selectedYear = activeYear.id.toString();
    selectedSem = activeSem.id.toString();

    setState(() {});
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

          enrolledstud.sort((a, b) {
            int yearComparison = b.syid.compareTo(a.syid);
            if (yearComparison != 0) return yearComparison;
            return b.semid.compareTo(a.semid);
          });

          if (enrolledstud.isNotEmpty) {
            EnrolledStud mostRecent = enrolledstud.first;
            syid = mostRecent.syid;
            semid = mostRecent.semid;
            levelid = mostRecent.levelid;
            sectionid = mostRecent.sectionid;

            selectedYear = syid.toString();
            selectedSem = semid.toString();
          }

          print('Initial Enrollment info: ${enrolledstud.first}');
          print('Initial Grade Level: $levelid');
        }
      });

      getStudSchedule(semid);
    });
  }

  void updateSelectedEnrollment(int selectedSyid, int selectedSemid) {
    EnrolledStud? selectedEnrollment = enrolledstud.firstWhere(
      (info) => info.syid == selectedSyid && info.semid == selectedSemid,
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

    setState(() {
      levelid = selectedEnrollment.levelid;
      sectionid = selectedEnrollment.sectionid;

      syid = selectedSyid;
      semid = selectedSemid;
    });

    print('Updated Enrollment info: $selectedEnrollment');
    print('Updated Grade Level: $levelid');

    getStudSchedule(semid);
  }

  getUser() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final json = preferences.getString('user');

    user = json == null ? UserData.myUser : User.fromJson(jsonDecode(json));
  }

  EnrolledStud? getSelectedEnrollmentInfo() {
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

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      loading = true;
    });

    await getUser();
    await getSchoolInfo();
    await getYearandSem();
    await getEnrolledStud();
    await getStudSchedule(semid);

    setState(() {
      loading = false;
    });

    print('Selected year: $selectedYear');
    print('Selected sem: $selectedSem');
  }

  Map<String, List<SchedItem>> _groupItemsByDay(List<SchedItem> items) {
    Map<String, List<SchedItem>> groupedItems = {};

    for (var item in items) {
      if (!groupedItems.containsKey(item.month)) {
        groupedItems[item.month] = [];
      }
      groupedItems[item.month]!.add(item);
    }

    // groupedItems.forEach((key, value) {
    //   value.sort((a, b) {
    //     final timeA = parseTime(a.start);
    //     final timeB = parseTime(b.start);
    //     return timeA.compareTo(timeB);
    //   });
    // });

    // Remove duplicates within each day and sort by time
  groupedItems.forEach((key, value) {
    // Create unique items using a map
    final uniqueItems = <String, SchedItem>{};
    for (var item in value) {
      final uniqueKey =
          '${item.subject}_${item.start}_${item.end}_${item.room}_${item.teacher}';
      uniqueItems[uniqueKey] = item;
    }

    // Replace the list with unique sorted items
    groupedItems[key] = uniqueItems.values.toList()
      ..sort((a, b) {
        final timeA = parseTime(a.start);
        final timeB = parseTime(b.start);
        return timeA.compareTo(timeB);
      });
  });

    return groupedItems;
  }

  getStudSchedule(int index) async {
    months.clear();
    selectedMonth = '';
    listOfItem2.clear();
    listOfSched.clear();

    await CallApi().getSchedule(user.id, syid, index, sectionid, levelid).then((
      response,
    ) {
      Iterable list = json.decode(response.body);

      setState(() {
        for (var element in list) {
          var ll = element['schedule'];

          for (var el in ll) {
            List<SchedItem> listOfItem = [];

            if (el['day'] != null && el['sched'] != null) {
              var sched = el['sched'];

              if (sched != null && sched.isNotEmpty) {
                for (var item in sched) {
                  if (item['start'] != null) {
                    var schedItem = SchedItem(
                      month: el['day'],
                      start: item['start'] ?? '',
                      end: item['end'] ?? '',
                      subject: item['subject'] ?? '',
                      room: item['room'] ?? '',
                      teacher: item['teacher'] ?? '',
                    );
                    listOfItem.add(schedItem);
                    listOfItem2.add(schedItem);
                  }
                }

                // Add day only if it's not already in the list (avoid duplicates)
                if (!months.contains(el['day'])) {
                  months.add(el['day']);
                }
              }
            }

            listOfSched.add(SchedData(day: el['day'], sched: listOfItem));
          }

          semid = index;
          if (listOfSched.isNotEmpty) {
            selectedMonth = listOfSched[0].day;
          }
        }
      });
    });
  }

  DateTime parseTime(String timeString) {
    try {
      if (timeString == null || timeString.trim().isEmpty) {
        return DateTime(2000);
      }
      final cleaned = timeString.trim().toUpperCase();

      final format = DateFormat('hh:mm a');

      return format.parse(cleaned);
    } catch (e) {
      return DateTime(2000);
    }
  }

  EnrolledStud _emptyEnrollment() => EnrolledStud(
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
  );

  void _onYearChanged(String value) {
    setState(() {
      selectedYear = value;
      syid = int.parse(selectedYear);

      EnrolledStud? selectedEnrollment = enrolledstud.firstWhere(
        (enrollment) => enrollment.syid == syid,
        orElse: () {
          ShadToaster.of(context).show(
            const ShadToast(description: Text('No schedule for this school year')),
          );
          return _emptyEnrollment();
        },
      );

      levelid = selectedEnrollment.levelid;
      sectionid = selectedEnrollment.sectionid;
    });
    if (selectedYear.isNotEmpty && selectedSem.isNotEmpty) {
      getStudSchedule(int.parse(semid.toString()));
    }
  }

  void _onSemChanged(String value) {
    setState(() {
      selectedSem = value;
      semid = int.parse(selectedSem);
    });
    if (selectedYear.isNotEmpty && selectedSem.isNotEmpty) {
      getStudSchedule(semid);
    }
  }

  /// School colour for small icon accents; falls back to the theme primary until it loads
  /// (and lightens in dark mode so it stays readable).
  Color _accent(BuildContext context) {
    final theme = ShadTheme.of(context);
    if (schoolColor.a == 0) return theme.colorScheme.primary;
    return Theme.of(context).brightness == Brightness.dark
        ? Color.lerp(schoolColor, Colors.white, 0.4)!
        : schoolColor;
  }

  @override
  Widget build(BuildContext context) {
    final showSem = levelid == 14 || levelid == 15 || levelid >= 17;
    return AppPage(
      title: 'Class schedule',
      body: loading
          ? const LoadingSkeleton()
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _FieldSelect(
                        label: 'School year',
                        value: selectedYear.isNotEmpty ? selectedYear : null,
                        options: [for (final y in schoolYear) (y.id.toString(), y.sydesc)],
                        onChanged: _onYearChanged,
                      ),
                    ),
                    if (showSem) ...[
                      Gap.wMd,
                      Expanded(
                        child: _FieldSelect(
                          label: 'Semester',
                          value: selectedSem.isNotEmpty ? selectedSem : null,
                          options: [for (final s in schoolSem) (s.id.toString(), s.semester)],
                          onChanged: _onSemChanged,
                        ),
                      ),
                    ],
                  ],
                ),
                Gap.hLg,
                if (levelid == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: Gap.xxl),
                    child: EmptyState(
                      title: 'No class schedule available',
                      message: 'There is no schedule for the selected school year and semester.',
                      icon: LucideIcons.calendarX,
                    ),
                  )
                else ...[
                  _FieldSelect(
                    label: 'Day',
                    value: months.contains(selectedMonth) || selectedMonth == 'All'
                        ? selectedMonth
                        : null,
                    options: [for (final m in ['All', ...months]) (m, m)],
                    onChanged: (v) => setState(() => selectedMonth = v),
                  ),
                  Gap.hXl,
                  ..._scheduleChildren(context),
                ],
              ],
            ),
    );
  }

  List<Widget> _scheduleChildren(BuildContext context) {
    final accent = _accent(context);
    if (selectedMonth == 'All' && listOfItem2.isNotEmpty) {
      return [
        for (final entry in _groupItemsByDay(listOfItem2).entries)
          _DayCard(title: entry.key, items: entry.value, accent: accent),
      ];
    }
    if (selectedMonth.isNotEmpty && listOfItem2.isNotEmpty) {
      return buildFilteredScheduleList(accent);
    }
    return [
      Padding(
        padding: const EdgeInsets.only(top: Gap.xxl),
        child: selectedYear == '' || selectedSem == ''
            ? const EmptyState(
                title: 'Select school year and semester',
                message: 'Pick both to load the schedule.',
                icon: LucideIcons.calendarDays,
              )
            : const EmptyState(
                title: 'No available schedule',
                icon: LucideIcons.calendarX,
              ),
      ),
    ];
  }

  List<Widget> buildFilteredScheduleList(Color accent) {
    // Filter by selected month
    List<SchedItem> filteredList = selectedMonth == 'All'
        ? List.from(listOfItem2)
        : listOfItem2
            .where(
              (item) =>
                  item.month.toLowerCase() ==
                  selectedMonth.toLowerCase(),
            )
            .toList();

    // Remove duplicates by creating a unique set based on key attributes
    final uniqueItems = <String, SchedItem>{};
    for (var item in filteredList) {
      final key =
          '${item.month}_${item.subject}_${item.start}_${item.end}_${item.room}_${item.teacher}';
      uniqueItems[key] = item;
    }

    // Convert back to list and sort by time
    final uniqueFilteredList = uniqueItems.values.toList()
      ..sort((a, b) => parseTime(a.start).compareTo(parseTime(b.start)));

    if (uniqueFilteredList.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: Gap.xxl),
          child: EmptyState(title: 'No available schedule', icon: LucideIcons.calendarX),
        ),
      ];
    }

    return [_DayCard(title: selectedMonth, items: uniqueFilteredList, accent: accent)];
  }
}

/// One card per day: a heading, then a row per class (time column, subject, teacher and room).
class _DayCard extends StatelessWidget {
  const _DayCard({required this.title, required this.items, required this.accent});

  final String title;
  final List<SchedItem> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return AppCard(
      padding: Gap.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.large),
          for (final item in items) ...[
            Gap.hMd,
            Divider(height: 1, color: theme.colorScheme.border),
            Gap.hMd,
            _ClassRow(item: item, accent: accent),
          ],
        ],
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.item, required this.accent});

  final SchedItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final text = ShadTheme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.start, style: text.small.copyWith(fontWeight: FontWeight.w600)),
              Text(item.end, style: text.muted),
            ],
          ),
        ),
        Gap.wMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.subject,
                style: text.p.copyWith(fontWeight: FontWeight.w600),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.teacher.isNotEmpty || item.room.isNotEmpty) Gap.hXs,
              if (item.teacher.isNotEmpty)
                _Meta(icon: LucideIcons.user, text: item.teacher, color: accent),
              if (item.room.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.xs),
                  child: _Meta(icon: LucideIcons.doorOpen, text: item.room, color: accent),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small icon + muted text line. Wraps instead of clipping.
class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: IconSize.inline, color: color),
        ),
        Gap.wSm,
        Flexible(child: Text(text, style: theme.textTheme.muted)),
      ],
    );
  }
}

/// Labelled shadcn select. Rebuilds when [value] changes from outside (year changes the
/// semester), because [ShadSelect] only reads its initial value once.
class _FieldSelect extends StatelessWidget {
  const _FieldSelect({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = ShadTheme.of(context).textTheme;
    String labelOf(String v) {
      for (final o in options) {
        if (o.$1 == v) return o.$2;
      }
      return v;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.small),
        Gap.hXs,
        LayoutBuilder(
          builder: (context, constraints) => ShadSelect<String>(
            key: ValueKey('$label-$value-${options.length}'),
            minWidth: constraints.maxWidth,
            maxWidth: constraints.maxWidth,
            placeholder: Text('Select ${label.toLowerCase()}'),
            initialValue: value,
            options: [
              for (final o in options) ShadOption<String>(value: o.$1, child: Text(o.$2)),
            ],
            selectedOptionBuilder: (context, v) =>
                Text(labelOf(v), maxLines: 1, overflow: TextOverflow.ellipsis),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}
