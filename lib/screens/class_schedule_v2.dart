import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pushtrial/api/api.dart';
import 'package:pushtrial/models/enrolled_stud.dart';
import 'package:pushtrial/models/schedule_v2.dart';
import 'package:pushtrial/models/school_info.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/models/user_data.dart';
import 'package:pushtrial/models/year_sem.dart';
import 'package:pushtrial/widgets/ui/ui.dart';
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

  bool loading = true;

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
    setState(() => loading = true);
    try {
      final response = await CallApi().getV2ClassSchedule(studid, syid, semid);
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
                Gap.hXl,
                if (subjects.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: Gap.xxl),
                    child: EmptyState(
                      title: 'No subjects found',
                      message: 'There is no schedule for the selected school year.',
                      icon: LucideIcons.calendarX,
                    ),
                  )
                else
                  for (final subj in subjects) _buildSubjectCard(subj),
              ],
            ),
    );
  }

  Widget _buildSubjectCard(V2Subject subj) {
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;
    final accent = _accent(context);
    return AppCard(
      padding: Gap.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(subj.subjdesc, style: text.large, maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
              if (subj.subjcode.isNotEmpty) ...[
                Gap.wSm,
                ShadBadge.secondary(child: Text(subj.subjcode)),
              ],
            ],
          ),
          if (subj.teacherName.isNotEmpty) ...[
            Gap.hSm,
            _Meta(icon: LucideIcons.user, text: subj.teacherName, color: accent),
          ],
          Gap.hMd,
          Divider(height: 1, color: theme.colorScheme.border),
          Gap.hMd,
          if (subj.schedule.isEmpty)
            _Meta(icon: LucideIcons.clock, text: 'No schedule assigned', color: accent, muted: true)
          else
            for (var i = 0; i < subj.schedule.length; i++) ...[
              if (i > 0) Gap.hMd,
              _buildSlot(subj.schedule[i], accent),
            ],
        ],
      ),
    );
  }

  Widget _buildSlot(V2ScheduleSlot slot, Color accent) {
    final text = ShadTheme.of(context).textTheme;
    final hasTime = slot.start.isNotEmpty || slot.end.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (slot.day.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Text(slot.day, style: text.p.copyWith(fontWeight: FontWeight.w600)),
          ),
        Wrap(
          spacing: Gap.lg,
          runSpacing: Gap.xs,
          children: [
            if (hasTime)
              _Meta(
                icon: LucideIcons.clock,
                text: '${slot.start} - ${slot.end}',
                color: accent,
                muted: true,
              ),
            if (slot.room.isNotEmpty)
              _Meta(icon: LucideIcons.doorOpen, text: slot.room, color: accent, muted: true),
            if (slot.type.isNotEmpty)
              _Meta(icon: LucideIcons.tag, text: slot.type, color: accent, muted: true),
          ],
        ),
      ],
    );
  }
}

/// Small icon + text line (teacher, time, room). Wraps instead of clipping.
class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, required this.color, this.muted = false});

  final IconData icon;
  final String text;
  final Color color;
  final bool muted;

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
        Flexible(
          child: Text(text, style: muted ? theme.textTheme.muted : theme.textTheme.small),
        ),
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
