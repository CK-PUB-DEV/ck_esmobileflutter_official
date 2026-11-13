import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pushtrial/core/api/api.dart';
import 'package:pushtrial/models/teacher_evaluation.dart';
import 'package:pushtrial/features/teacher_evaluation/teacher_evaluation_form_screen.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// The student's classes for a term, each with its teacher and whether it was evaluated yet.
/// Tapping a class that is still to do opens the questionnaire.
///
/// Uses the school's own teacher evaluation (same questions and records as the student portal).
/// Needs a v2 server; on an older one the page says the feature isn't available yet.
class TeacherEvaluationScreen extends StatefulWidget {
  const TeacherEvaluationScreen({super.key});

  @override
  State<TeacherEvaluationScreen> createState() => _TeacherEvaluationScreenState();
}

class _TeacherEvaluationScreenState extends State<TeacherEvaluationScreen> {
  bool _loading = true;
  bool _failed = false;

  /// Null when the school's server has no v2 yet.
  TeacherEvaluationData? _data;
  bool _serverTooOld = false;

  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({EvaluationPeriod? period}) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final response = await CallApi().getTeacherEvaluation(syid: period?.syid, semid: period?.semid);
      if (response == null) {
        setState(() {
          _serverTooOld = true;
          _loading = false;
        });
        return;
      }
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final body = json.decode(response.body);
      setState(() {
        _data = TeacherEvaluationData.fromJson(Map<String, dynamic>.from(body as Map));
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _open(EvaluationClass item) async {
    final data = _data!;
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TeacherEvaluationFormScreen(
          item: item,
          form: data.form!,
          period: data.period!,
          department: data.department,
        ),
      ),
    );
    if (submitted == true) _load(period: data.period);
  }

  @override
  Widget build(BuildContext context) {
    const title = 'Teacher evaluation';
    if (_loading) {
      return const AppPage(title: title, body: LoadingSkeleton(cards: 4));
    }
    if (_serverTooOld) {
      return const AppPage(
        title: title,
        body: EmptyState(
          icon: LucideIcons.clipboardList,
          title: 'Not available right now',
          message: 'Your school has not turned this on in the app yet. You can still evaluate your teachers on the student portal.',
        ),
      );
    }
    if (_failed || _data == null) {
      return AppPage(title: title, body: ErrorState(onRetry: () => _load(period: _data?.period)));
    }

    final data = _data!;
    if (!data.available) {
      return AppPage(
        title: title,
        body: EmptyState(
          icon: LucideIcons.clipboardList,
          title: data.reason == 'not_college' ? 'For college students' : 'Not used at your school',
          message: data.reason == 'not_college'
              ? 'Teacher evaluation is for college students. There is nothing to evaluate for this account.'
              : 'Your school does not use teacher evaluation.',
        ),
      );
    }

    final theme = ShadTheme.of(context);
    final total = data.classes.length;
    return AppPage(
      title: title,
      onRefresh: () => _load(period: data.period),
      children: [
        // Progress: the one thing the page is for.
        HeroCard(
          label: 'Teacher evaluation',
          icon: LucideIcons.clipboardList,
          value: total == 0 ? 'No classes' : '${data.done} of $total',
          captions: [total == 0 ? 'Nothing to evaluate this term' : 'classes evaluated'],
          pill: data.period?.label,
          progress: total == 0 ? null : data.done / total,
        ),
        if (data.periods.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: ShadSelect<int>(
              initialValue: data.periods.indexWhere((p) => p.same(data.period!)),
              minWidth: double.infinity,
              options: [
                for (var i = 0; i < data.periods.length; i++)
                  ShadOption(value: i, child: Text(data.periods[i].label)),
              ],
              selectedOptionBuilder: (context, i) => Text(data.periods[i].label),
              onChanged: (i) {
                if (i != null && !data.periods[i].same(data.period!)) _load(period: data.periods[i]);
              },
            ),
          ),
        if (!data.canSubmit)
          AppCard(
            child: Row(
              children: [
                Icon(LucideIcons.info, size: 18, color: theme.colorScheme.mutedForeground),
                Gap.wSm,
                Expanded(
                  child: Text(
                    'Only the student can submit evaluations. Sign in with the student account to answer them.',
                    style: theme.textTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        if (total == 0)
          const Padding(
            padding: EdgeInsets.only(top: Gap.xl),
            child: EmptyState(
              icon: LucideIcons.bookOpen,
              title: 'No classes',
              message: 'You have no classes with a teacher assigned this term.',
            ),
          ),
        for (final item in data.classes)
          ListRow(
            margin: const EdgeInsets.only(bottom: Gap.md),
            title: item.subject,
            subtitle: [item.subjectCode, if (item.teacher.isNotEmpty) item.teacher].join(' · '),
            onTap: !item.submitted && data.canSubmit ? () => _open(item) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                item.submitted
                    ? const StatusBadge('Done', status: AppStatus.success)
                    : const StatusBadge('To do', status: AppStatus.warning),
                if (!item.submitted && data.canSubmit) ...[
                  Gap.wXs,
                  Icon(LucideIcons.chevronRight, size: 18, color: theme.colorScheme.mutedForeground),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
