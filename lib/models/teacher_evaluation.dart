/// Teacher evaluation, as the school's v2 server describes it (`api/mobile/v2/teacher_evaluation`).
library;

int _int(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
String _str(dynamic v) => v == null ? '' : '$v';
List<dynamic> _list(dynamic v) => v is List ? v : const [];

class EvaluationPeriod {
  const EvaluationPeriod(this.syid, this.semid, this.label);

  factory EvaluationPeriod.fromJson(Map<String, dynamic> j) =>
      EvaluationPeriod(_int(j['syid']), _int(j['semid']), _str(j['label']));

  final int syid;
  final int semid;
  final String label;

  bool same(EvaluationPeriod other) => other.syid == syid && other.semid == semid;
}

class ScaleLevel {
  const ScaleLevel(this.score, this.label, this.description);

  factory ScaleLevel.fromJson(Map<String, dynamic> j) =>
      ScaleLevel(_int(j['score']), _str(j['label']), _str(j['description']));

  final int score;
  final String label;
  final String description;
}

class EvaluationQuestion {
  const EvaluationQuestion(this.no, this.text);

  factory EvaluationQuestion.fromJson(Map<String, dynamic> j) =>
      EvaluationQuestion(_int(j['no']), _str(j['text']));

  final int no;
  final String text;
}

class EvaluationComment {
  const EvaluationComment(this.key, this.label);

  factory EvaluationComment.fromJson(Map<String, dynamic> j) =>
      EvaluationComment(_str(j['key']), _str(j['label']));

  final String key;
  final String label;
}

class EvaluationForm {
  const EvaluationForm(this.intro, this.scale, this.questions, this.comments);

  factory EvaluationForm.fromJson(Map<String, dynamic> j) => EvaluationForm(
        _str(j['intro']),
        [for (final s in _list(j['scale'])) ScaleLevel.fromJson(s)]
          ..sort((a, b) => b.score.compareTo(a.score)),
        [for (final q in _list(j['questions'])) EvaluationQuestion.fromJson(q)],
        [for (final c in _list(j['comments'])) EvaluationComment.fromJson(c)],
      );

  final String intro;
  final List<ScaleLevel> scale;
  final List<EvaluationQuestion> questions;
  final List<EvaluationComment> comments;
}

class EvaluationClass {
  const EvaluationClass({
    required this.schedcodeid,
    required this.subjectCode,
    required this.subject,
    required this.teacher,
    required this.submitted,
    this.submittedAt,
  });

  factory EvaluationClass.fromJson(Map<String, dynamic> j) => EvaluationClass(
        schedcodeid: _int(j['schedcodeid']),
        subjectCode: _str(j['subjectcode']),
        subject: _str(j['subject']),
        teacher: _str(j['teacher']),
        submitted: j['submitted'] == true,
        submittedAt: j['submitted_at'] == null ? null : DateTime.tryParse('${j['submitted_at']}'),
      );

  final int schedcodeid;
  final String subjectCode;
  final String subject;
  final String teacher;
  final bool submitted;
  final DateTime? submittedAt;
}

/// The whole answer for one term. When [available] is false, [reason] says why:
/// `not_set_up` (the school doesn't use teacher evaluation) or `not_college` (only college
/// students evaluate their teachers).
class TeacherEvaluationData {
  const TeacherEvaluationData({
    required this.available,
    this.reason = '',
    this.canSubmit = false,
    this.period,
    this.periods = const [],
    this.department = '',
    this.form,
    this.classes = const [],
  });

  factory TeacherEvaluationData.fromJson(Map<String, dynamic> j) {
    if (j['available'] != true) {
      return TeacherEvaluationData(available: false, reason: _str(j['reason']));
    }
    return TeacherEvaluationData(
      available: true,
      canSubmit: j['can_submit'] == true,
      period: j['period'] is Map ? EvaluationPeriod.fromJson(Map<String, dynamic>.from(j['period'])) : null,
      periods: [for (final p in _list(j['periods'])) EvaluationPeriod.fromJson(p)],
      department: _str(j['department']),
      form: j['form'] is Map ? EvaluationForm.fromJson(Map<String, dynamic>.from(j['form'])) : null,
      classes: [for (final c in _list(j['subjects'])) EvaluationClass.fromJson(c)],
    );
  }

  final bool available;
  final String reason;
  final bool canSubmit;
  final EvaluationPeriod? period;
  final List<EvaluationPeriod> periods;
  final String department;
  final EvaluationForm? form;
  final List<EvaluationClass> classes;

  int get done => classes.where((c) => c.submitted).length;
}
