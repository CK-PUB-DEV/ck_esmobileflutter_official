import 'package:flutter/material.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';
import 'package:pushtrial/models/user_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/core/api/api.dart';
import 'package:pushtrial/models/enrolled_student.dart';
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
  String? _pickedDay;
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

  getStudSchedule(int index) async {
    months.clear();
    _pickedDay = null;
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

  bool get _showSem => levelid == 14 || levelid == 15 || levelid >= 17;

  void _openPicker() {
    showPickerSheet(
      context,
      title: 'School year and semester',
      child: StatefulBuilder(
        builder: (context, setSheet) {
          final showSem = _showSem;
          return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FieldSelect(
              label: 'School year',
              value: selectedYear.isNotEmpty ? selectedYear : null,
              options: [for (final y in schoolYear) (y.id.toString(), y.sydesc)],
              onChanged: (v) {
                _onYearChanged(v);
                setSheet(() {});
              },
            ),
            if (showSem) ...[
              Gap.hMd,
              _FieldSelect(
                label: 'Semester',
                value: selectedSem.isNotEmpty ? selectedSem : null,
                options: [for (final s in schoolSem) (s.id.toString(), s.semester)],
                onChanged: (v) {
                  _onSemChanged(v);
                  setSheet(() {});
                },
              ),
            ],
          ],
          );
        },
      ),
    );
  }

  /// "SY 2025-2026 · 1st Semester" for the context pill.
  String? _heroPill(bool showSem) {
    final year = schoolYear.where((y) => y.id.toString() == selectedYear).map((y) => y.sydesc).firstOrNull;
    if (year == null) return null;
    final sem = showSem
        ? schoolSem.where((x) => x.id.toString() == selectedSem).map((x) => x.semester).firstOrNull
        : null;
    return sem == null ? 'SY $year' : 'SY $year · $sem';
  }

  /// How many different classes the week holds (the same row repeated is counted once).
  int get _classCount => {
    for (final i in listOfItem2) '${i.month}_${i.subject}_${i.start}_${i.end}_${i.room}_${i.teacher}',
  }.length;

  @override
  Widget build(BuildContext context) {
    final showSem = _showSem;
    final text = ShadTheme.of(context).textTheme;
    final pill = _heroPill(showSem);

    // Weekday chips in week order; anything that is not a weekday goes under "Other".
    final days = [for (final m in months) if (_dayOrder(m) != 99) m]
      ..sort((a, b) => _dayOrder(a).compareTo(_dayOrder(b)));
    if (months.any((m) => _dayOrder(m) == 99)) days.add(_otherDay);
    final today = _todayIndex();
    String? day;
    if (days.isNotEmpty) {
      day = days.contains(_pickedDay)
          ? _pickedDay
          : (days.where((d) => _dayOrder(d) == today).firstOrNull ?? days.first);
    }

    return AppPage(
      title: 'Class schedule',
      body: loading
          ? const LoadingSkeleton()
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
              children: [
                Row(
                  children: [
                    Flexible(
                      child: IntrinsicWidth(
                        child: ContextPill(
                          label: pill ?? 'Select school year',
                          icon: LucideIcons.calendarClock,
                          onTap: _openPicker,
                        ),
                      ),
                    ),
                    if (levelid != 0 && listOfItem2.isNotEmpty) ...[
                      Gap.wMd,
                      Text('$_classCount classes', style: text.muted),
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
                else
                  ..._scheduleChildren(days, day, today),
              ],
            ),
    );
  }

  List<Widget> _scheduleChildren(List<String> days, String? day, int today) {
    if (listOfItem2.isEmpty || day == null) {
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

    // Remove duplicates, then sort by start time.
    final unique = <String, SchedItem>{};
    for (final item in listOfItem2) {
      final matches = day == _otherDay
          ? _dayOrder(item.month) == 99
          : item.month.toLowerCase() == day.toLowerCase();
      if (!matches) continue;
      unique['${item.month}_${item.subject}_${item.start}_${item.end}_${item.room}_${item.teacher}'] = item;
    }
    final items = unique.values.toList()
      ..sort((a, b) => parseTime(a.start).compareTo(parseTime(b.start)));

    return [
      FilterChips<String>(
        options: [
          for (final d in days)
            (value: d, label: d == _otherDay ? d : (d.length > 3 ? d.substring(0, 3) : d)),
        ],
        value: day,
        onChanged: (v) => setState(() => _pickedDay = v),
      ),
      Gap.hLg,
      if (items.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: Gap.xxl),
          child: EmptyState(title: 'No available schedule', icon: LucideIcons.calendarX),
        )
      else
        for (final item in items)
          _TimelineRow(
            start: item.start,
            end: item.end,
            subject: item.subject,
            teacher: item.teacher,
            room: item.room,
            live: _isLive(item, today),
          ),
    ];
  }

  bool _isLive(SchedItem item, int today) {
    if (_dayOrder(item.month) != today) return false;
    final start = _minutes(item.start);
    final end = _minutes(item.end);
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    return start >= 0 && end > start && nowMin >= start && nowMin < end;
  }
}

/// Chip value for classes whose day is not a weekday.
const _otherDay = 'Other';

const _weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// 0 = Monday ... 6 = Sunday; 99 when the text is not a weekday.
int _dayOrder(String day) {
  final p = day.trim().toLowerCase();
  if (p.length < 3) return 99;
  final i = _weekdays.indexOf(p.substring(0, 3));
  return i < 0 ? 99 : i;
}

int _todayIndex() => DateTime.now().weekday - 1;

/// Minutes since midnight for "7:30 AM" / "07:30" / "13:05:00"; -1 when it cannot be read.
int _minutes(String t) {
  final m = RegExp(r'(\d{1,2}):(\d{2})(?::\d{2})?\s*([aApP][mM])?').firstMatch(t);
  if (m == null) return -1;
  var h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  final ap = m.group(3)?.toLowerCase();
  if (ap == 'pm' && h < 12) h += 12;
  if (ap == 'am' && h == 12) h = 0;
  return h * 60 + min;
}

/// Timeline row: start/end time on the left, a rounded card with the class on the right.
/// The class happening now is filled with the school colour.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.start,
    required this.end,
    required this.subject,
    required this.teacher,
    required this.room,
    required this.live,
  });

  final String start;
  final String end;
  final String subject;
  final String teacher;
  final String room;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;
    final tone = SchoolTone.current(context);
    final muted = theme.colorScheme.mutedForeground;
    const tabular = [FontFeature.tabularFigures()];
    final metaColor = live ? tone.onSolid.withValues(alpha: 0.85) : muted;
    final metaStyle = text.muted.copyWith(color: metaColor);

    Widget meta(IconData icon, String value) => Padding(
          padding: const EdgeInsets.only(top: Gap.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: IconSize.inline, color: metaColor),
              ),
              Gap.wSm,
              Expanded(child: Text(value, style: metaStyle)),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Padding(
              padding: const EdgeInsets.only(top: Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(start, style: text.smallStrong.copyWith(fontFeatures: tabular)),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(end, style: text.muted.copyWith(fontFeatures: tabular)),
                  ),
                ],
              ),
            ),
          ),
          Gap.wSm,
          Expanded(
            child: Container(
              width: double.infinity,
              padding: Gap.card,
              decoration: BoxDecoration(
                color: live ? tone.solid : theme.colorScheme.card,
                borderRadius: BorderRadius.circular(AppRadius.row),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject,
                    style: live ? text.strong.copyWith(color: tone.onSolid) : text.strong,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (teacher.isNotEmpty) meta(LucideIcons.user, teacher),
                  if (room.isNotEmpty) meta(LucideIcons.doorOpen, room),
                ],
              ),
            ),
          ),
        ],
      ),
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
