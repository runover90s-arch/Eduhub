import 'dart:convert';

List<dynamic> asList(dynamic value) => value is List ? value : const [];
Map<String, dynamic> asMap(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
String asText(dynamic value, [String fallback = '']) => value?.toString() ?? fallback;
int asInt(dynamic value, [int fallback = 0]) => value is num ? value.toInt() : int.tryParse(asText(value)) ?? fallback;
double asDouble(dynamic value, [double fallback = 0]) => value is num ? value.toDouble() : double.tryParse(asText(value)) ?? fallback;

class Exam {
  const Exam({required this.id, required this.title, required this.subject, required this.grade,
    required this.minutes, required this.difficulty, required this.access,
    required this.summary, required this.status, required this.questionCount,
    this.demoQuestions = const []});
  final String id, title, subject, difficulty, access, summary, status;
  final int grade, minutes, questionCount;
  final List<ExamQuestion> demoQuestions;

  factory Exam.fromJson(Map<String, dynamic> json) {
    final questions = asList(json['questions']).map((e) => ExamQuestion.fromJson(asMap(e))).toList();
    return Exam(
      id: asText(json['id']), title: asText(json['title']), subject: asText(json['subject']),
      grade: asInt(json['grade'], 12), minutes: asInt(json['duration_minutes'], 45),
      difficulty: asText(json['difficulty'], 'Trung bình'),
      access: asText(json['access_level'], 'free'),
      summary: asText(json['description']), status: asText(json['status'], 'published'),
      questionCount: asInt(json['question_count'], questions.length), demoQuestions: questions,
    );
  }
}

class ExamQuestion {
  const ExamQuestion({required this.id, required this.position, required this.kind,
    required this.prompt, this.options = const [], this.statements = const [],
    this.pairs = const [], this.answer, this.explanation = '', this.imageUrl = '', this.points = 1});
  final String id, kind, prompt, explanation, imageUrl;
  final int position;
  final double points;
  final List<String> options;
  final List<String> statements;
  final List<Map<String, String>> pairs;
  final dynamic answer;

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    final pairs = asList(json['pairs']).map((e) => asMap(e).map((k, v) => MapEntry(k, asText(v)))).toList();
    return ExamQuestion(
      id: asText(json['id']), position: asInt(json['position'], 1),
      kind: asText(json['kind'], 'single'), prompt: asText(json['prompt']),
      options: asList(json['options']).map((e) => asText(e)).toList(),
      statements: asList(json['statements']).map((e) => asText(e)).toList(),
      pairs: pairs, answer: json['answer'], explanation: asText(json['explanation']),
      imageUrl: asText(json['image_url']),points: asDouble(json['points'], 1),
    );
  }
}

class Lesson {
  const Lesson({required this.id, required this.title, required this.subject,
    required this.grade, required this.summary, required this.body, required this.access,
    required this.minutes, required this.status});
  final String id, title, subject, summary, body, access, status;
  final int grade, minutes;
  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: asText(json['id']), title: asText(json['title']), subject: asText(json['subject']),
    grade: asInt(json['grade'], 12), summary: asText(json['description']),
    body: asText(json['body']), access: asText(json['access_level'], 'free'),
    minutes: asInt(json['duration_minutes'], 15), status: asText(json['status'], 'published'),
  );
}

class StudyPackage {
  const StudyPackage({required this.id, required this.title, required this.description,
    required this.price, required this.days, required this.combo});
  final String id, title, description;
  final int price, days;
  final bool combo;
  factory StudyPackage.fromJson(Map<String, dynamic> j) => StudyPackage(
    id: asText(j['id']), title: asText(j['title']), description: asText(j['description']),
    price: asInt(j['price_vnd']), days: asInt(j['duration_days'], 30), combo: j['is_combo'] == true,
  );
}

class ExamResult {
  const ExamResult({required this.examId, required this.sessionId,
    required this.academicScore, required this.finalScore, required this.penalties,
    required this.correct, required this.wrong, required this.skipped,
    required this.pending, required this.details, required this.finishedAt});
  final String examId, sessionId;
  final double academicScore, finalScore;
  final int penalties, correct, wrong, skipped, pending;
  final Map<String, dynamic> details;
  final DateTime finishedAt;
  factory ExamResult.fromJson(Map<String, dynamic> j) => ExamResult(
    examId: asText(j['exam_id']), sessionId: asText(j['session_id']),
    academicScore: asDouble(j['academic_score']), finalScore: asDouble(j['final_score']),
    penalties: asInt(j['penalty_count']), correct: asInt(j['correct_count']),
    wrong: asInt(j['wrong_count']), skipped: asInt(j['skipped_count']), pending: asInt(j['pending_count']),
    details: asMap(j['details']), finishedAt: DateTime.tryParse(asText(j['created_at'])) ?? DateTime.now(),
  );
  Map<String, dynamic> toJson() => {
    'exam_id':examId, 'session_id':sessionId, 'academic_score':academicScore,
    'final_score':finalScore,'penalty_count':penalties,'correct_count':correct,
    'wrong_count':wrong,'skipped_count':skipped,'pending_count':pending,
    'details':details,'created_at':finishedAt.toIso8601String(),
  };
}

// String values in JSON are encoded for the local history cache; actual
// exam answer keys remain on the Supabase server when connected.
String packJson(Object value) => jsonEncode(value);
