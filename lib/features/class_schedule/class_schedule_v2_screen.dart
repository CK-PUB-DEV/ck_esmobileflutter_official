import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pushtrial/core/api/api.dart';
import 'package:pushtrial/models/enrolled_student.dart';
import 'package:pushtrial/models/schedule_v2.dart';
import 'package:pushtrial/models/school_info.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/models/user_data.dart';
import 'package:pushtrial/models/year_sem.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClassScheduleV2Screen extends StatefulWidget {
  const ClassScheduleV2Screen({super.key});

  @override
  State<ClassScheduleV2Screen> createState() => _ClassScheduleV2ScreenState();
}

class _ClassScheduleV2ScreenState extends State<ClassScheduleV2Screen> {

  // Slow responses can finish after the screen was closed; skip the update then.
  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }
  User user = UserData.myUser;
  String studid = '0';

  List<V2Subject> subjects = [];
  List<EnrolledStud> enrolledstud = [];
  List<SchoolYear> schoolYear = [];
  List<Sem> schoolSem = [];
  List<SchoolInfo> schoolInfo = [];

  Color schoolColor = const Color.fromARGB(0, 0, 0, 0);

  int syid = 0;
  int semid = 0;
  int levelid = 0;
  String selectedYear = '';
  String selectedSem = '';
  String? _selectedDay;

  bool loading = true;
  // Set when the schedule could not be loaded, so the page offers Retry instead of looking empty.
  bool _failed = false;

  Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 7 || hexString.length == 9) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => loading = true);
    final prefs = await SharedPreferences.getInstance();
    studid = prefs.getString('studid') ?? '0';
    final userJson = prefs.getString('user');
    if (userJson != null) user = User.fromJson(jsonDecode(userJson));

    await _loadSchoolInfo();
    await _loadYearAndSem();
    await _loadEnrolledStud();
    await _loadSchedule();

    setState(() => loading = false);
  }

  Future<void> _loadSchoolInfo() async {
    try {
      final response = await CallApi().getSchoolInfo();
      final parsed = json.decode(response.body);
      if (parsed is List && parsed.isNotEmpty && mounted) {
        setState(() {
          schoolInfo = parsed.map((e) => SchoolInfo.fromJson(e)).toList();
          schoolColor = hexToColor(schoolInfo[0].schoolcolor);
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
    } catch (_) {}
  }

  Future<void> _loadEnrolledStud() async {
    try {
      final response = await CallApi().getEnrolledStud(user.id);
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        final list = decoded['enrolledstud_info'] as List;
        enrolledstud = list.map((e) => EnrolledStud.fromJson(e)).toList();
        enrolledstud.sort((a, b) {
          final y = b.syid.compareTo(a.syid);
          return y != 0 ? y : b.semid.compareTo(a.semid);
        });

        if (enrolledstud.isNotEmpty) {
          final latest = enrolledstud.first;
          syid = latest.syid;
          semid = latest.semid;
          levelid = latest.levelid;
          selectedYear = syid.toString();
          selectedSem = semid.toString();
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSchedule() async {
    if (syid == 0) return;
    setState(() {
      loading = true;
      _failed = false;
    });
    try {
      final response = await CallApi().getV2ClassSchedule(studid, syid, semid);
      if (response.statusCode != 200) _failed = true;
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List && mounted) {
          setState(() {
            subjects = decoded.map((e) => V2Subject.fromJson(e)).toList();
          });
        }
      }
    } catch (e) {
      print('V2 schedule error: $e');
      _failed = true;
    }
    if (mounted) setState(() => loading = false);
  }

  void _onYearChanged(String value) {
    setState(() {
      selectedYear = value;
      syid = int.parse(value);

      final enrolled = enrolledstud.firstWhere(
        (e) => e.syid == syid,
        orElse: () => enrolledstud.first,
      );
      semid = enrolled.semid;
      levelid = enrolled.levelid;
      selectedSem = semid.toString();
      subjects = [];
    });
    _loadSchedule();
  }

  void _onSemChanged(String value) {
    setState(() {
      selectedSem = value;
      semid = int.parse(value);
      subjects = [];
    });
    _loadSchedule();
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

  @override
  Widget build(BuildContext context) {
    final showSem = _showSem;
    final text = ShadTheme.of(context).textTheme;

    // One entry per class slot, so the timeline can be filtered by day and sorted by time.
    final entries = <({V2Subject subj, V2ScheduleSlot slot})>[
      for (final s in subjects)
        for (final slot in s.schedule) (subj: s, slot: slot),
    ];
    final days = <String>[];
    for (final e in entries) {
      if (e.slot.day.isNotEmpty && !days.contains(e.slot.day)) days.add(e.slot.day);
    }
    days.sort((a, b) => _dayOrder(a).compareTo(_dayOrder(b)));
    // Slots without a day stay reachable under an "Other" chip.
    if (entries.any((e) => e.slot.day.isEmpty)) days.add(_otherDay);
    final today = _todayIndex();
    String? day;
    if (days.isNotEmpty) {
      day = days.contains(_selectedDay)
          ? _selectedDay
          : (days.where((d) => _dayOrder(d) == today).firstOrNull ?? days.first);
    }
    final visible = [
      for (final e in entries)
        if (day == null ||
            (day == _otherDay ? e.slot.day.isEmpty : e.slot.day == day))
          e,
    ]..sort((a, b) => _minutes(a.slot.start).compareTo(_minutes(b.slot.start)));
    final unscheduled = [for (final s in subjects) if (s.schedule.isEmpty) s];
    final pill = _heroPill(showSem);

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
                    if (subjects.isNotEmpty) ...[
                      Gap.wMd,
                      Text(
                        '${subjects.length} subject${subjects.length == 1 ? '' : 's'}',
                        style: text.muted,
                      ),
                    ],
                  ],
                ),
                Gap.hLg,
                if (subjects.isEmpty && _failed)
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.xxl),
                    child: ErrorState(
                      title: 'Could not load your schedule',
                      onRetry: _loadSchedule,
                    ),
                  )
                else if (subjects.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: Gap.xxl),
                    child: EmptyState(
                      title: 'No subjects found',
                      message: 'There is no schedule for the selected school year.',
                      icon: LucideIcons.calendarX,
                    ),
                  )
                else ...[
                  if (days.isNotEmpty) ...[
                    FilterChips<String>(
                      options: [
                        for (final d in days)
                          (value: d, label: d == _otherDay ? d : (d.length > 3 ? d.substring(0, 3) : d)),
                      ],
                      value: day!,
                      onChanged: (v) => setState(() => _selectedDay = v),
                    ),
                    Gap.hLg,
                  ],
                  for (final e in visible)
                    _TimelineRow(
                      start: e.slot.start,
                      end: e.slot.end,
                      subject: e.subj.subjdesc,
                      detail: [e.subj.subjcode, e.slot.type].where((s) => s.trim().isNotEmpty).join(' · '),
                      teacher: e.subj.teacherName,
                      room: e.slot.room,
                      live: _isLive(e.slot, today),
                    ),
                  if (unscheduled.isNotEmpty) ...[
                    Gap.hMd,
                    Text('No schedule assigned', style: text.muted),
                    Gap.hSm,
                    for (final s in unscheduled)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gap.xs),
                        child: Text(s.subjdesc, style: text.small),
                      ),
                  ],
                ],
              ],
            ),
    );
  }

  bool _isLive(V2ScheduleSlot slot, int today) {
    if (_dayOrder(slot.day) != today) return false;
    final start = _minutes(slot.start);
    final end = _minutes(slot.end);
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    return start >= 0 && end > start && nowMin >= start && nowMin < end;
  }
}

/// Chip value for slots that carry no day.
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
    required this.detail,
    required this.teacher,
    required this.room,
    required this.live,
  });

  final String start;
  final String end;
  final String subject;
  final String detail;
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
                  if (detail.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: Gap.xs),
                      child: Text(detail, style: metaStyle),
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
