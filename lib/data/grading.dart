import 'models.dart';

bool isUnanswered(dynamic response) {
  if (response == null) return true;
  if (response is String) return response.trim().isEmpty;
  if (response is List) return response.isEmpty || response.any((value) => value == null);
  if (response is Map) return response.isEmpty || response.values.any((value) => value == null || value == '');
  return false;
}

bool answersMatch(ExamQuestion question, dynamic response) {
  if (isUnanswered(response)) return false;
  switch (question.kind) {
    case 'single':
      return response == question.answer;
    case 'multiple':
      if (response is! List || question.answer is! List) return false;
      final selected = response.map((e) => e.toString()).toSet();
      final expected = (question.answer as List).map((e) => e.toString()).toSet();
      return selected.length == expected.length && selected.containsAll(expected);
    case 'true_false':
      if (response is! List || question.answer is! List) return false;
      final expected = question.answer as List;
      return response.length == expected.length &&
          List.generate(expected.length, (i) => response[i] == expected[i]).every((v) => v);
    case 'short':
      final a = response.toString().trim().replaceAll(',', '.');
      final b = question.answer.toString().trim().replaceAll(',', '.');
      final numericA = num.tryParse(a);
      final numericB = num.tryParse(b);
      if (numericA != null && numericB != null) return (numericA - numericB).abs() < 1e-9;
      return a.toLowerCase() == b.toLowerCase();
    case 'matching':
      final expected = asMap(question.answer);
      final actual = asMap(response);
      return expected.length == actual.length && expected.keys.every((key) => expected[key] == actual[key]);
    case 'essay':
    default:
      return false;
  }
}

class GradeCalculator {
  static ExamResult calculate(String examId, String sessionId, List<ExamQuestion> questions,
      Map<String, dynamic> answers, int validIncidents) {
    var totalPoints = 0.0;
    var earnedPoints = 0.0;
    var correct = 0, wrong = 0, skipped = 0, pending = 0;
    final details = <String, dynamic>{};
    for (final q in questions) {
      final value = answers[q.id];
      totalPoints += q.points;
      final empty = isUnanswered(value);
      if (empty) {
        skipped++;
        details[q.id] = {..._snapshot(q),'status':'skipped','chosen':value,'answer':q.answer,'explanation':q.explanation};
      } else if (q.kind == 'essay') {
        pending++;
        details[q.id] = {..._snapshot(q),'status':'pending','chosen':value,'answer':null,'explanation':q.explanation};
      } else if (answersMatch(q, value)) {
        correct++;
        earnedPoints += q.points;
        details[q.id] = {..._snapshot(q),'status':'correct','chosen':value,'answer':q.answer,'explanation':q.explanation};
      } else {
        wrong++;
        details[q.id] = {..._snapshot(q),'status':'wrong','chosen':value,'answer':q.answer,'explanation':q.explanation};
      }
    }
    final score = totalPoints > 0 ? (earnedPoints / totalPoints * 1000).round() / 100 : 0.0;
    return ExamResult(
      examId: examId, sessionId: sessionId, academicScore: score,
      finalScore: (score - validIncidents).clamp(0.0, 10.0).toDouble(),
      penalties: validIncidents, correct: correct, wrong: wrong,
      skipped: skipped, pending: pending, details: details, finishedAt: DateTime.now(),
    );
  }
}

// Preserve the original question in history even if an exam is archived later.
Map<String,dynamic> _snapshot(ExamQuestion q)=>{
  'position':q.position,'prompt':q.prompt,'kind':q.kind,
  'options':q.options,'statements':q.statements,'pairs':q.pairs,'points':q.points,'image_url':q.imageUrl,
};
