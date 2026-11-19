import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pushtrial/core/api/api.dart';
import 'package:pushtrial/models/teacher_evaluation.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// The school's questionnaire for one class: a score for every question, the two comments and
/// the department. Pops `true` once the evaluation is saved (or was already saved).
class TeacherEvaluationFormScreen extends StatefulWidget {
  const TeacherEvaluationFormScreen({
    super.key,
    required this.item,
    required this.form,
    required this.period,
    required this.department,
  });

  final EvaluationClass item;
  final EvaluationForm form;
  final EvaluationPeriod period;
  final String department;

  @override
  State<TeacherEvaluationFormScreen> createState() => _TeacherEvaluationFormScreenState();
}

class _TeacherEvaluationFormScreenState extends State<TeacherEvaluationFormScreen> {
  final Map<int, int> _scores = {};
  late final TextEditingController _department = TextEditingController(text: widget.department);
  late final Map<String, TextEditingController> _comments = {
    for (final c in widget.form.comments) c.key: TextEditingController(),
  };

  /// Set after a submit attempt, so missing answers are highlighted only from then on.
  bool _showMissing = false;
  bool _sending = false;

  @override
  void dispose() {
    _department.dispose();
    for (final c in _comments.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String message, {bool error = false}) {
    ShadToaster.of(context).show(
      error ? ShadToast.destructive(description: Text(message)) : ShadToast(description: Text(message)),
    );
  }

  String? _problem() {
    if (_scores.length < widget.form.questions.length) return 'Please answer every question.';
    for (final c in widget.form.comments) {
      if (_comments[c.key]!.text.trim().isEmpty) return 'Please fill in "${c.label}".';
    }
    if (_department.text.trim().isEmpty) return 'Please enter your department.';
    return null;
  }

  Future<void> _submit() async {
    final problem = _problem();
    if (problem != null) {
      setState(() => _showMissing = true);
      _toast(problem, error: true);
      return;
    }

    final confirmed = await showConfirmSheet(
      context,
      title: 'Submit evaluation?',
      message: 'You can’t change it after it is submitted.',
      confirmLabel: 'Submit',
      cancelLabel: 'Go back',
      icon: LucideIcons.send,
    );
    if (!confirmed || !mounted) return;

    setState(() => _sending = true);
    try {
      final response = await CallApi().submitTeacherEvaluation({
        'syid': widget.period.syid,
        'semid': widget.period.semid,
        'schedcodeid': widget.item.schedcodeid,
        'department': _department.text.trim(),
        'scores': {for (final e in _scores.entries) '${e.key}': e.value},
        for (final c in widget.form.comments) c.key: _comments[c.key]!.text.trim(),
      });
      if (!mounted) return;
      String message = '';
      try {
        final body = json.decode(response.body);
        if (body is Map && body['message'] != null) message = '${body['message']}';
      } catch (_) {}

      if (response.statusCode == 200 || response.statusCode == 409) {
        _toast(message.isNotEmpty ? message : 'Your evaluation was submitted.');
        Navigator.of(context).pop(true);
        return;
      }
      _toast(message.isNotEmpty ? message : 'Could not submit. Please try again.', error: true);
    } catch (_) {
      if (mounted) _toast('Could not submit. Check your connection and try again.', error: true);
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final answered = _scores.length;
    final total = widget.form.questions.length;

    // Same header as every other inner screen. The submit bar is part of the body, which
    // AppPage keeps clear of the system navigation bar.
    return AppPage(
      title: 'Evaluate teacher',
      body: Column(
        children: [
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
              children: [
                HeroCard(
                  label: widget.period.label,
                  icon: LucideIcons.userRound,
                  value: widget.item.teacher.isEmpty ? 'Teacher' : widget.item.teacher,
                  captions: ['${widget.item.subjectCode} · ${widget.item.subject}'],
                ),
                AppCard(
                  title: 'Department',
                  child: ShadInput(controller: _department, placeholder: const Text('e.g. CELA')),
                ),
                _ScaleGuide(scale: widget.form.scale),
                SectionHeader(widget.form.intro.isEmpty ? 'Questions' : widget.form.intro),
                for (final q in widget.form.questions)
                  _QuestionCard(
                    question: q,
                    scale: widget.form.scale,
                    value: _scores[q.no],
                    missing: _showMissing && !_scores.containsKey(q.no),
                    onChanged: (v) => setState(() => _scores[q.no] = v),
                  ),
                const SectionHeader('Comments'),
                for (final c in widget.form.comments)
                  AppCard(
                    title: c.label,
                    child: ShadInput(
                      controller: _comments[c.key],
                      minLines: 3,
                      maxLines: 6,
                      placeholder: const Text('Write your answer'),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.row)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(child: Text('$answered of $total answered', style: theme.textTheme.muted)),
                Gap.wMd,
                ShadButton(
                  height: kTapTarget,
                  decoration: appPillDecoration(),
                  onPressed: _sending ? null : _submit,
                  leading: _sending
                      ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.send, size: IconSize.inline),
                  child: const Text('Submit'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What each score means, folded away until asked for.
class _ScaleGuide extends StatelessWidget {
  const _ScaleGuide({required this.scale});

  final List<ScaleLevel> scale;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: Gap.lg),
          childrenPadding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
          title: Text('Rating guide', style: theme.textTheme.p.copyWith(fontWeight: FontWeight.w600)),
          children: [
            for (final s in scale)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 28, child: Text('${s.score}', style: theme.textTheme.large)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.label, style: theme.textTheme.p.copyWith(fontWeight: FontWeight.w600)),
                          Text(s.description, style: theme.textTheme.muted),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One question with a 5-to-1 score picker. Turns red when it is still unanswered after the
/// student tried to submit.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.scale,
    required this.value,
    required this.missing,
    required this.onChanged,
  });

  final EvaluationQuestion question;
  final List<ScaleLevel> scale;
  final int? value;
  final bool missing;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final tone = SchoolTone.current(context);
    final chosen = scale.where((s) => s.score == value).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      // Still unanswered after a submit attempt: a red ring around the whole card.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.row),
          border: missing ? Border.all(color: theme.colorScheme.destructive, width: 1.5) : null,
        ),
        child: RoundedCard(
          radius: AppRadius.row,
          margin: EdgeInsets.zero,
          padding: Gap.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${question.no}. ${question.text}', style: theme.textTheme.p),
              Gap.hMd,
              Row(
                children: [
                  for (final s in scale) ...[
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: s.score == value,
                        label: 'Score ${s.score}, ${s.label}',
                        excludeSemantics: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => onChanged(s.score),
                          child: Container(
                            height: kTapTarget,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: s.score == value ? tone.solid : theme.colorScheme.muted,
                            ),
                            child: Text(
                              '${s.score}',
                              style: theme.textTheme.p.copyWith(
                                fontWeight: FontWeight.w700,
                                color: s.score == value ? tone.onSolid : theme.colorScheme.foreground,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (s != scale.last) Gap.wXs,
                  ],
                ],
              ),
              Gap.hSm,
              Text(
                chosen?.label ?? (missing ? 'Choose a score' : '5 = ${scale.first.label}, 1 = ${scale.last.label}'),
                style: missing && chosen == null
                    ? theme.textTheme.small.copyWith(color: theme.colorScheme.destructive)
                    : theme.textTheme.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
