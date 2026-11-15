import 'package:flutter_test/flutter_test.dart';
import 'package:eduhub/data/grading.dart';
import 'package:eduhub/data/models.dart';

void main() {
  test('short numeric answer accepts Vietnamese decimal comma', () {
    const q = ExamQuestion(id:'1',position:1,kind:'short',prompt:'Số?',answer:'2.5');
    expect(answersMatch(q,'2,5'),isTrue);
    expect(answersMatch(q,'2.500'),isTrue);
    expect(answersMatch(q,'3'),isFalse);
  });
  test('multiple selection ignores answer ordering but not extra selection', () {
    const q=ExamQuestion(id:'2',position:2,kind:'multiple',prompt:'Chọn',answer:['A','C']);
    expect(answersMatch(q,['C','A']),isTrue);
    expect(answersMatch(q,['C','A','D']),isFalse);
  });
  test('true/false requires every substatement answered', () {
    const q=ExamQuestion(id:'3',position:3,kind:'true_false',prompt:'Đúng sai',answer:[true,false,true]);
    expect(isUnanswered([true,null,true]),isTrue);
    expect(answersMatch(q,[true,false,true]),isTrue);
    expect(answersMatch(q,[true,true,true]),isFalse);
  });
  test('matching uses labeled pair ids', () {
    const q=ExamQuestion(id:'4',position:4,kind:'matching',prompt:'Nối',answer:{'A':'2','B':'1'});
    expect(answersMatch(q,{'A':'2','B':'1'}),isTrue);
    expect(answersMatch(q,{'A':'1','B':'2'}),isFalse);
  });
  test('G2 deducts one point per incident on ten-point scale', () {
    const questions=[
      ExamQuestion(id:'q1',position:1,kind:'single',prompt:'Câu 1',answer:'A'),
      ExamQuestion(id:'q2',position:2,kind:'single',prompt:'Câu 2',answer:'B'),
    ];
    final grade=GradeCalculator.calculate('e','s',questions,{'q1':'A','q2':'B'},2);
    expect(grade.academicScore,10);
    expect(grade.finalScore,8);
    expect(grade.correct,2);
    expect(grade.wrong,0);
    expect(grade.skipped,0);
    final zero=GradeCalculator.calculate('e','s',questions,{'q1':'B','q2':'B'},15);
    expect(zero.finalScore,0);
  });
  test('essay is pending, never incorrectly marked wrong', () {
    const questions=[
      ExamQuestion(id:'a',position:1,kind:'single',prompt:'A',answer:'C'),
      ExamQuestion(id:'b',position:2,kind:'essay',prompt:'Giải thích',points:2),
    ];
    final score=GradeCalculator.calculate('exam','session',questions,{'a':'C','b':'Bài giải...'},0);
    expect(score.pending,1);
    expect(score.wrong,0);
    expect(score.correct,1);
    expect(score.academicScore,closeTo(3.33,.01));
  });
}
