import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushtrial/core/api/api.dart';
import 'package:pushtrial/models/grades.dart';
import 'package:pushtrial/models/school_info.dart';
import 'package:pushtrial/models/year_sem.dart';
import 'package:pushtrial/models/attendance.dart';
import 'package:pushtrial/models/observed_values.dart';
import 'package:pushtrial/models/enrolled_student.dart';
import 'package:pushtrial/core/services/grading_setup.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ReportCardScreen extends StatefulWidget {
  const ReportCardScreen({super.key});

  @override
  State<ReportCardScreen> createState() => _ReportCardScreenState();
}

class _ReportCardScreenState extends State<ReportCardScreen> {

  // Slow responses can finish after the screen was closed; skip the update then.
  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }
  /// Selected tab for K-12 and senior high: 'grades', 'attendance' or 'values'.
  String _tab = 'grades';

  var id = '0';
  var studid = '0';
  var syid = 0;
  var semid = 1;
  var gradelevel = 0;
  var sectionid = 0;
  var strand = 0;
  String selectedYear = '';
  String selectedSem = '';
  List<String> years = [];
  List<String> semesters = [];
  List<Grades> data = [];
  List<Grades> finalGrade = [];
  List<EnrolledStud> enrolledstud = [];
  List<Grades> concatenatedArray = [];
  List<SchoolYear> schoolYear = [];
  List<Sem> schoolSem = [];
  List<Attendance> attendance = [];
  List<StudentObservedValues> _studentObservedValues = [];
  List<RatingValues> _ratingValues = [];
  List<Setup> _setup = [];
  bool loading = true;
  bool _isLoadingCoreValues = false;
  bool _isLoadingAttendance = false;

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

    var activeYear = schoolYear.firstWhere((year) => year.isactive == 1);
    var activeSem = schoolSem.firstWhere((sem) => sem.isactive == 1);

    if (schoolYear.isNotEmpty) {
      selectedYear = activeYear.id.toString();
    }

    if (schoolSem.isNotEmpty) {
      selectedSem = activeSem.id.toString();
    }

    setState(() {
      selectedYear = activeYear.id.toString();
      selectedSem = activeSem.id.toString();
      syid = activeYear.id;
      semid = activeSem.id;
    });

    await getEnrolledStud();
  }

  getUser() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final json = preferences.getString('studid');
    if (json != null) {
      setState(() {
        id = json;
      });
    }
  }

  /// How this school grades the selected level (terms or quarters); quarters until the server says.
  GradingSetup _grading = GradingSetup.quarters;

  getGrades(int index) async {
    Iterable gdList = [];
    Iterable gdFinal = [];

    if (gradelevel > 0 && gradelevel < 17) {
      _grading = await GradingSetup.load(syid, gradelevel) ?? GradingSetup.quarters;
    }

    await CallApi()
        .getStudGrade(id, gradelevel, syid, sectionid, strand, index)
        .then((response) {
          setState(() {
            Iterable list = json.decode(response.body);

            for (var gd in list) {
              gdList = gd['grades'];

              if (gradelevel < 17) {
                gdFinal = gd['finalgrade'];
              }
            }

            if (gradelevel < 17) {
              data = gdList.map((model) {
                return Grades.fromJson(model);
              }).toList();
            } else {
              data = gdList.map((model) {
                return Grades(
                  syid: model['syid'] ?? 0,
                  semid: model['semid'] ?? 0,
                  subjcode: model['subjcode']?.toString() ?? '',
                  subjdesc: model['subjdesc']?.toString() ?? '',
                  q1: model['prelemgrade']?.toString() ?? '0',
                  q2: model['midtermgrade']?.toString() ?? '0',
                  q3: model['prefigrade']?.toString() ?? '0',
                  q4: model['finalgrade']?.toString() ?? '0',
                  q1status: model['q1status']?.toString() ?? '',
                  q2status: model['q2status']?.toString() ?? '',
                  q3status: model['q3status']?.toString() ?? '',
                  q4status: model['q4status']?.toString() ?? '',
                  prelemgrade: model['prelemgrade']?.toString() ?? '',
                  midtermgrade: model['midtermgrade']?.toString() ?? '',
                  prefigrade: model['prefigrade']?.toString() ?? '',
                  finalgrade: model['finalgrade']?.toString() ?? '',
                  prelemstatus: model['prelemstatus']?.toString() ?? '',
                  midtermstatus: model['midtermstatus']?.toString() ?? '',
                  prefistatus: model['prefistatus']?.toString() ?? '',
                  finalstatus: model['finalstatus']?.toString() ?? '',
                  finalrating: model['finalgrade']?.toString() ?? '',
                  fg: model['fg']?.toString() ?? '',
                  fgremarks: model['fgremarks']?.toString() ?? '',
                  actiontaken: model['actiontaken']?.toString() ?? '',
                );
              }).toList();
            }

            if (gradelevel == 14 || gradelevel == 15) {
              finalGrade = gdFinal.map((ave) {
                return ave['semid'].toString() == index.toString()
                    ? Grades.parseAverage(ave)
                    : Grades(
                        syid: 0,
                        semid: 0,
                        subjcode: '',
                        q1: '',
                        q2: '',
                        q3: '',
                        q4: '',
                        q1status: '',
                        q2status: '',
                        q3status: '',
                        q4status: '',
                        prelemgrade: '',
                        midtermgrade: '',
                        prefigrade: '',
                        finalgrade: '',
                        prelemstatus: '',
                        midtermstatus: '',
                        prefistatus: '',
                        finalstatus: '',
                        finalrating: '',
                        fg: '',
                        actiontaken: '',
                        fgremarks: '',
                        subjdesc: '',
                      );
              }).toList();
            }

            semid = index;
            concatenatedArray = [...data, ...finalGrade];
            concatenatedArray = concatenatedArray
                .where(
                  (grade) =>
                      grade.subjcode.isNotEmpty &&
                      grade.subjdesc != "GENERAL AVERAGE",
                )
                .toList();
          });
        });
  }

  getEnrolledStud() async {
    await CallApi().getEnrolledStud(id).then((response) {
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
            gradelevel = mostRecent.levelid;
            sectionid = mostRecent.sectionid;
            strand = mostRecent.strandid;
            selectedYear = syid.toString();
            selectedSem = semid.toString();
          }
        }
      });

      getGrades(semid);
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
      gradelevel = selectedEnrollment.levelid;
      sectionid = selectedEnrollment.sectionid;
      strand = selectedEnrollment.strandid;
      syid = selectedSyid;
      semid = selectedSemid;
    });

    getGrades(semid);
  }

  void _resetGradeData() {
    setState(() {
      concatenatedArray = [];
      data = [];
      finalGrade = [];
    });
  }

  getStudentAttendance() async {
    setState(() {
      _isLoadingAttendance = true;
    });

    final response = await CallApi().getStudentAttendance(id, selectedYear);

    // The server answers {"attendance_setup": [...]} for an enrolled student, and a bare list
    // ([{"att_setup": []}]) when there is no basic-ed or senior-high enrollment that year
    // (college students, for example): that means no attendance to show.
    attendance = [];
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map && decoded['attendance_setup'] is List) {
        attendance = (decoded['attendance_setup'] as List)
            .map((data) => Attendance.fromJson(data))
            .toList();
      }
    } catch (_) {
      // Not JSON (an error page): leave attendance empty.
    }

    // Senior high servers send the calendar rows without a semester next to the per-semester rows,
    // with the same months and different school days. Use only the selected semester's rows then;
    // K-12 only has rows without a semester, which are kept as they are.
    if (attendance.any((record) => record.semid != 0)) {
      attendance = attendance.where((record) => record.semid == semid).toList();
    }

    setState(() {
      _isLoadingAttendance = false;
    });
  }

  getObservedValues() async {
    setState(() {
      _isLoadingCoreValues = true;
    });
    final response = await CallApi().getObservedValues(id, selectedYear);
    // Like attendance: an object for an enrolled student, a one-item list of empty values
    // otherwise. Read the first item in that case.
    Map<String, dynamic> responseData = const {};
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        responseData = decoded;
      } else if (decoded is List && decoded.isNotEmpty && decoded.first is Map<String, dynamic>) {
        responseData = decoded.first as Map<String, dynamic>;
      }
    } catch (_) {}

    List listOf(String key) => responseData[key] is List ? responseData[key] as List : const [];

    _ratingValues = listOf('ob_rv').map((data) => RatingValues.fromJson(data)).toList();
    _setup = listOf('ob_setup').map((data) => Setup.fromJson(data)).toList();
    _studentObservedValues =
        listOf('student_ob').map((data) => StudentObservedValues.fromJson(data)).toList();

    setState(() {
      _isLoadingCoreValues = false;
    });
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
    getStudentAttendance();

    setState(() {
      loading = false;
    });
  }

  bool get _isCollege => gradelevel >= 17;
  bool get _isShs => gradelevel == 14 || gradelevel == 15;
  bool get _isDcc =>
      schoolInfo.isNotEmpty &&
      schoolInfo[0].abbreviation == 'DCC' &&
      gradelevel >= 17;

  String get _levelLabel => _isCollege ? 'College' : (_isShs ? 'SHS' : 'K-12');

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

      final selectedEnrollment = enrolledstud.firstWhere(
        (enrollment) => enrollment.syid == syid,
        orElse: () {
          ShadToaster.of(context).show(
            const ShadToast(description: Text('No grades for this school year')),
          );
          return _emptyEnrollment();
        },
      );

      gradelevel = selectedEnrollment.levelid;
      sectionid = selectedEnrollment.sectionid;
    });
    if (selectedYear.isNotEmpty && selectedSem.isNotEmpty) {
      getGrades(int.parse(semid.toString()));
    }
  }

  void _onSemChanged(String value) {
    _resetGradeData();
    setState(() {
      selectedSem = value;
      semid = int.parse(value);
    });
    updateSelectedEnrollment(syid, semid);
  }

  void _onTabChanged(String value) {
    setState(() => _tab = value);
    if (value == 'attendance') getStudentAttendance();
    if (value == 'values') getObservedValues();
  }

  /// "SY 2025-2026 · 1st Semester" for the hero card.
  String? _heroPill() {
    final year = schoolYear.where((y) => y.id.toString() == selectedYear).map((y) => y.sydesc).firstOrNull;
    if (year == null) return null;
    final sem = (gradelevel >= 14 && gradelevel != 16)
        ? schoolSem.where((x) => x.id.toString() == selectedSem).map((x) => x.semester).firstOrNull
        : null;
    return sem == null ? 'SY $year' : 'SY $year · $sem';
  }

  void _openPeriodPicker() {
    showPickerSheet(
      context,
      title: 'School year and semester',
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FieldSelect(
              label: 'School year',
              value: selectedYear.isNotEmpty ? selectedYear : null,
              options: [for (final y in schoolYear) (y.id.toString(), y.sydesc)],
              onChanged: (v) {
                _onYearChanged(v);
                setSheetState(() {});
              },
            ),
            if (gradelevel >= 14 && gradelevel != 16) ...[
              Gap.hMd,
              _FieldSelect(
                label: 'Semester',
                value: selectedSem.isNotEmpty ? selectedSem : null,
                options: [for (final s in schoolSem) (s.id.toString(), s.semester)],
                onChanged: (v) {
                  _onSemChanged(v);
                  setSheetState(() {});
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    final count = concatenatedArray.length;
    return HeroCard(
      label: 'Report card',
      icon: LucideIcons.graduationCap,
      value: '$count subject${count == 1 ? '' : 's'}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Report card',
      actions: loading
          ? null
          : [
              Padding(
                padding: const EdgeInsets.only(right: Gap.lg),
                child: Center(child: SchoolPill(_levelLabel, SchoolTone.current(context))),
              ),
            ],
      body: loading
          ? const LoadingSkeleton()
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
              children: [
                if (concatenatedArray.isNotEmpty && (_isCollege || _tab == 'grades'))
                  _buildHero(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ContextPill(
                    label: _heroPill() ?? 'Select school year',
                    icon: LucideIcons.calendarDays,
                    onTap: _openPeriodPicker,
                  ),
                ),
                Gap.hLg,
                if (_isCollege)
                  ..._gradesChildren()
                else ...[
                  PillToggle<String>(
                    value: _tab,
                    onChanged: _onTabChanged,
                    options: const [
                      (value: 'grades', label: 'Grades'),
                      (value: 'attendance', label: 'Attendance'),
                      (value: 'values', label: 'Core values'),
                    ],
                  ),
                  Gap.hLg,
                  if (_tab == 'grades')
                    ..._gradesChildren()
                  else if (_tab == 'attendance')
                    ..._attendanceChildren()
                  else
                    ..._coreValuesChildren(),
                ],
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Grades
  // ---------------------------------------------------------------------------

  List<Widget> _gradesChildren() {
    if (concatenatedArray.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: Gap.xxl),
          child: EmptyState(
            title: 'No grades available',
            message: 'There are no grades for the selected school year and semester.',
            icon: LucideIcons.graduationCap,
          ),
        ),
      ];
    }
    final rows = [for (final grade in concatenatedArray) (grade: grade, data: _subjectData(grade))];
    final headers = rows.first.data.cells.map((c) => c.label).toList();
    final hasSummaries = rows.any((r) => r.data.summaries.isNotEmpty);
    return [
      if (headers.isNotEmpty)
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.md),
          child: _GradeTable(
            headers: headers,
            rows: [
              for (final r in rows)
                _TableRowData(
                  title: r.grade.subjdesc,
                  values: [for (final c in r.data.cells) c.value],
                ),
            ],
          ),
        ),
      if (hasSummaries) ...[
        const SectionHeader('Final ratings'),
        for (final r in rows)
          for (final s in r.data.summaries) _finalRatingRow(r.grade, s),
      ],
    ];
  }

  Widget _finalRatingRow(Grades grade, _Summary summary) {
    final hasValue = summary.value.trim().isNotEmpty;
    final label = summary.label;
    final tail = hasValue ? '$label ${summary.value.trim()}' : '$label —';
    final subtitle = grade.subjcode.isEmpty ? tail : '${grade.subjcode} · $tail';
    return ListRow(
      title: grade.subjdesc,
      subtitle: subtitle,
      trailing: summary.remark.isEmpty
          ? null
          : StatusBadge(
              summary.remark,
              status: summary.remark == 'PASSED' ? AppStatus.success : AppStatus.danger,
            ),
    );
  }

  /// A period value is shown only once it has been released (status 4).
  String _period(String value, String status) =>
      value != 'null' && status == '4' ? value : '';

  ({List<_Cell> cells, List<_Summary> summaries}) _subjectData(Grades grade) {
    final cells = <_Cell>[];
    final summaries = <_Summary>[];

    if (_isCollege) {
      if (_isDcc) {
        final released = grade.finalstatus == '4';
        summaries.add(
          _Summary(
            'Final grade',
            released ? grade.finalgrade : '',
            released ? grade.fgremarks : '',
          ),
        );
      } else {
        cells.addAll([
          _Cell('Prelim', grade.prelemstatus == '4' ? grade.prelemgrade : ''),
          _Cell('Midterm', grade.midtermstatus == '4' ? grade.midtermgrade : ''),
          _Cell('Pre-final', grade.prefistatus == '4' ? grade.prefigrade : ''),
          _Cell('Final', grade.finalstatus == '4' ? grade.finalgrade : ''),
        ]);
        final all = grade.prelemstatus == '4' &&
            grade.midtermstatus == '4' &&
            grade.prefistatus == '4' &&
            grade.finalstatus == '4';
        summaries.add(
          _Summary('Final grade', all ? grade.fg : '', all ? grade.fgremarks : ''),
        );
      }
    } else if (_isShs && _grading.mode != 'term') {
      final first = semid == 1 || semid == 0;
      final second = semid == 2 || semid == 0;
      if (first) {
        cells.addAll([
          _Cell('Q1', _period(grade.q1, grade.q1status)),
          _Cell('Q2', _period(grade.q2, grade.q2status)),
        ]);
      }
      if (second) {
        cells.addAll([
          _Cell('Q3', _period(grade.q3, grade.q3status)),
          _Cell('Q4', _period(grade.q4, grade.q4status)),
        ]);
      }
      final both = first && second;
      if (first) {
        final done = grade.q1status == '4' && grade.q2status == '4';
        summaries.add(
          _Summary(
            both ? 'Final rating, 1st semester' : 'Final rating',
            done && grade.finalrating != 'null' ? grade.finalrating : '',
            done ? grade.actiontaken : '',
          ),
        );
      }
      if (second) {
        final done = grade.q3status == '4' && grade.q4status == '4';
        summaries.add(
          _Summary(
            both ? 'Final rating, 2nd semester' : 'Final rating',
            done && grade.finalrating != 'null' ? grade.finalrating : '',
            done ? grade.actiontaken : '',
          ),
        );
      }
    } else {
      // The school's own periods: four quarters, or three terms (the 4th slot is then unused and
      // must not hold back the final rating).
      final values = [grade.q1, grade.q2, grade.q3, grade.q4];
      final statuses = [grade.q1status, grade.q2status, grade.q3status, grade.q4status];
      for (final p in _grading.periods) {
        cells.add(_Cell(p.label, _period(values[p.no - 1], statuses[p.no - 1])));
      }
      final all = _grading.periods.every((p) => statuses[p.no - 1] == '4');
      summaries.add(
        _Summary(
          'Final rating',
          all && grade.finalrating != 'null' ? grade.finalrating : '',
          all ? grade.actiontaken : '',
        ),
      );
    }

    return (cells: cells, summaries: summaries);
  }

  // ---------------------------------------------------------------------------
  // Attendance
  // ---------------------------------------------------------------------------

  List<Widget> _attendanceChildren() {
    if (_isLoadingAttendance) return const [_LoadingBlocks()];
    if (attendance.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: Gap.xxl),
          child: EmptyState(
            title: 'No attendance records',
            message: 'Attendance has not been recorded for this school year.',
            icon: LucideIcons.calendarDays,
          ),
        ),
      ];
    }

    final totalDays = attendance.fold(0, (sum, record) => sum + record.days);
    final totalPresent = attendance.fold(0, (sum, record) => sum + record.present);
    final totalAbsent = attendance.fold(0, (sum, record) => sum + record.absent);
    final theme = ShadTheme.of(context);

    return [
      AppCard(
        child: Column(
          children: [
            const _AttendanceRow(
              month: 'Month',
              days: 'School days',
              present: 'Present',
              absent: 'Absent',
              header: true,
            ),
            for (final record in attendance) ...[
              Divider(height: Gap.lg, color: theme.colorScheme.border),
              _AttendanceRow(
                month: record.monthdesc,
                days: record.days.toString(),
                present: record.present.toString(),
                absent: record.absent.toString(),
              ),
            ],
            Divider(height: Gap.lg, color: theme.colorScheme.border),
            _AttendanceRow(
              month: 'Total',
              days: totalDays.toString(),
              present: totalPresent.toString(),
              absent: totalAbsent.toString(),
              bold: true,
            ),
          ],
        ),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Core values
  // ---------------------------------------------------------------------------

  List<Widget> _coreValuesChildren() {
    if (_isLoadingCoreValues) return const [_LoadingBlocks()];
    if (_setup.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: Gap.xxl),
          child: EmptyState(
            title: 'No core values recorded',
            message: 'Observed values have not been entered for this school year.',
            icon: LucideIcons.clipboardList,
          ),
        ),
      ];
    }

    String ratingValue(int evalId) {
      return _ratingValues
          .firstWhere(
            (rating) => rating.id == evalId,
            orElse: () => RatingValues(id: 0, sort: '', gsid: 0, description: '', value: ''),
          )
          .value;
    }

    _TableRowData rowFor(Setup setup) {
      final observed = _studentObservedValues.firstWhere(
        (obs) => obs.gsdid == setup.id,
        orElse: () => StudentObservedValues(
          gsdid: setup.id,
          q1eval: 0,
          q2eval: 0,
          q3eval: 0,
          q4eval: 0,
        ),
      );
      return _TableRowData(
        title: setup.description,
        values: [
          ratingValue(observed.q1eval),
          ratingValue(observed.q2eval),
          ratingValue(observed.q3eval),
          ratingValue(observed.q4eval),
        ],
      );
    }

    return [
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.md),
        child: _GradeTable(
          headers: const ['Q1', 'Q2', 'Q3', 'Q4'],
          rows: [for (final setup in _setup) rowFor(setup)],
        ),
      ),
    ];
  }
}

class _Cell {
  const _Cell(this.label, this.value);
  final String label;
  final String value;
}

class _Summary {
  const _Summary(this.label, this.value, this.remark);
  final String label;
  final String value;
  final String remark;
}

class _TableRowData {
  const _TableRowData({required this.title, required this.values});
  final String title;
  final List<String> values;
}

const _tabular = [FontFeature.tabularFigures()];

/// Subjects (or core values) as rows, one column per period, in a single card. Fits the card
/// width, never scrolls sideways.
class _GradeTable extends StatelessWidget {
  const _GradeTable({required this.headers, required this.rows});

  final List<String> headers;
  final List<_TableRowData> rows;

  static const _subjectFlex = 5;
  static const _periodFlex = 2;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;
    Widget period(Widget child) => Expanded(
      flex: _periodFlex,
      child: Align(alignment: Alignment.centerRight, child: child),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: _subjectFlex, child: Text('Subject', style: text.muted)),
            for (final h in headers)
              period(FittedBox(fit: BoxFit.scaleDown, child: Text(h, style: text.muted))),
          ],
        ),
        for (final row in rows) ...[
          Divider(height: Gap.lg, color: theme.colorScheme.border),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: _subjectFlex,
                child: Padding(
                  padding: const EdgeInsets.only(right: Gap.sm),
                  child: Text(
                    row.title,
                    style: text.strong,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              for (final v in row.values)
                period(
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      v.trim().isEmpty ? '—' : v.trim(),
                      style: text.p.copyWith(
                        fontFeatures: _tabular,
                        color: v.trim().isEmpty
                            ? theme.colorScheme.mutedForeground
                            : theme.colorScheme.foreground,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.month,
    required this.days,
    required this.present,
    required this.absent,
    this.header = false,
    this.bold = false,
  });

  final String month;
  final String days;
  final String present;
  final String absent;
  final bool header;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final text = ShadTheme.of(context).textTheme;
    final base = header
        ? text.muted
        : (bold ? text.strong : text.p);
    final style = base.copyWith(fontFeatures: _tabular);
    Widget cell(String value, int flex, {TextAlign align = TextAlign.end}) => Expanded(
      flex: flex,
      child: Text(value, style: style, textAlign: align, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cell(month, 3, align: TextAlign.start),
        cell(days, 2),
        cell(present, 2),
        cell(absent, 2),
      ],
    );
  }
}

class _LoadingBlocks extends StatelessWidget {
  const _LoadingBlocks();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonBox(height: 96, radius: AppRadius.row),
        Gap.hMd,
        SkeletonBox(height: 96, radius: AppRadius.row),
        Gap.hMd,
        SkeletonBox(height: 96, radius: AppRadius.row),
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
