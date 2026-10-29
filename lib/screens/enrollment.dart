import 'package:flutter/material.dart';
import 'package:pushtrial/models/enrolled_stud.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushtrial/api/api.dart';
import 'dart:convert';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/models/user_data.dart';
import 'package:pushtrial/models/enrollment_data.dart';
import 'package:pushtrial/models/year_sem.dart';
import 'package:pushtrial/widgets/ui/ui.dart';

class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({super.key});

  @override
  State<EnrollmentScreen> createState() => EnrollmentScreenState();
}

class EnrollmentScreenState extends State<EnrollmentScreen> {
  User user = UserData.myUser;
  String id = '0';
  int syid = 0;
  String selectedYear = '';
  List<EnrollmentData> enData = [];
  bool loading = true;
  List<SchoolYear> schoolYear = [];
  List<EnrolledStud> enrolledstud = [];

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
    await getYearandSem();
    await getEnrolledStud();
    setState(() {
      loading = false;
    });
  }

  Future<void> getYearandSem() async {
    final response = await CallApi().getYearandSem();
    final Map<String, dynamic> responseData = json.decode(response.body);

    schoolYear = (responseData['sy'] as List)
        .map((data) => SchoolYear.fromJson(data))
        .toList();

    schoolYear.sort((a, b) => a.sydesc.compareTo(b.sydesc));

    var activeYear = schoolYear.firstWhere((year) => year.isactive == 1);

    if (schoolYear.isNotEmpty) {
      selectedYear = activeYear.id.toString();
      syid = int.parse(selectedYear);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const AppPage(
        title: 'Enrollment information',
        body: LoadingSkeleton(cards: 2),
      );
    }

    final matches = enrolledstud
        .where((enrollment) => enrollment.syid == syid)
        .toList();

    return AppPage(
      title: 'Enrollment information',
      children: [
        ShadSelect<String>(
          initialValue: selectedYear.isNotEmpty ? selectedYear : null,
          placeholder: const Text('Choose a school year'),
          options: [
            for (final option in schoolYear)
              ShadOption(value: option.id.toString(), child: Text(option.sydesc)),
          ],
          selectedOptionBuilder: (context, value) {
            final match = schoolYear.where((y) => y.id.toString() == value);
            return Text(match.isEmpty ? value : match.first.sydesc);
          },
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              selectedYear = value;
              syid = int.parse(selectedYear);
            });
            getEnrolledStud();
          },
        ),
        Gap.hLg,
        if (matches.isEmpty)
          const SizedBox(
            height: 320,
            child: EmptyState(
              icon: LucideIcons.school,
              title: 'No enrollment found',
              message: 'There is no data for the selected school year.',
            ),
          )
        else
          for (final enrollment in matches) _enrollmentCard(enrollment),
      ],
    );
  }

  Widget _enrollmentCard(EnrolledStud enrollment) {
    final theme = ShadTheme.of(context);
    final status = enrollment.description;
    final enrolled =
        status.toLowerCase().contains('enrolled') &&
        !status.toLowerCase().contains('not');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  enrollment.sydesc,
                  style: theme.textTheme.large,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (status.isNotEmpty) ...[
                Gap.wSm,
                StatusBadge(
                  status,
                  status: enrolled ? AppStatus.success : AppStatus.neutral,
                ),
              ],
            ],
          ),
          Gap.hSm,
          if (enrollment.semester.isNotEmpty)
            InfoRow('Semester', enrollment.semester, icon: LucideIcons.calendar),
          InfoRow('Grade level', enrollment.levelname, icon: LucideIcons.graduationCap),
          if (enrollment.strandname.isNotEmpty)
            InfoRow('Strand', enrollment.strandname, icon: LucideIcons.bookOpen),
          if (enrollment.sectionname.isNotEmpty)
            InfoRow('Section', enrollment.sectionname, icon: LucideIcons.users),
          if (enrollment.courseDesc.isNotEmpty)
            InfoRow('Course', enrollment.courseDesc, icon: LucideIcons.bookOpen),
        ],
      ),
    );
  }

  Future<void> getUser() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final json = preferences.getString('studid');

    if (json != null) {
      setState(() {
        id = json;
      });
    }
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
        }
      });
    });
  }
}
