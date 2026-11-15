import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduhub/data/import_validation.dart';

void main(){
  final sample={
    'title':'Kiểm tra chương một','subject':'Toán học','grade':12,'duration_minutes':40,'access_level':'free',
    'questions':[
      {'kind':'single','prompt':r'Tính $f\u0027(x)$?','options':['1','2','3','4'],'answer':'B'},
      {'kind':'true_false','prompt':'Xác định đúng sai các phát biểu',
        'statements':['Phát biểu 1','Phát biểu 2'],'answer':[true,false]},
      {'kind':'matching','prompt':'Nối hai vế tương ứng',
        'options':['vế phải 1','vế phải 2'],'pairs':[{'label':'A','left':'a'},{'label':'B','left':'b'}],
        'answer':{'A':'2','B':'1'}},
      {'kind':'essay','prompt':'Giải thích và chứng minh','points':2},
    ]
  };
  test('import accepts a structured exam and assigns sequential question positions',(){
    final parsed=ExamImport.parse(jsonEncode(sample));
    expect(parsed.metadata['title'],'Kiểm tra chương một');
    expect(parsed.questions.length,4);
    expect(parsed.questions.last['position'],4);
    expect(parsed.questions.last['answer'],isNull);
  });
  test('import rejects an invalid single-choice answer',(){
    final data=jsonDecode(jsonEncode(sample)) as Map<String,dynamic>;
    (data['questions'] as List)[0]['answer']='G';
    expect(()=>ExamImport.parse(jsonEncode(data)),throwsFormatException);
  });
  test('import rejects incomplete true false array',(){
    final data=jsonDecode(jsonEncode(sample)) as Map<String,dynamic>;
    (data['questions'] as List)[1]['answer']=[true];
    expect(()=>ExamImport.parse(jsonEncode(data)),throwsFormatException);
  });
  test('import rejects incomplete matching answer map',(){
    final data=jsonDecode(jsonEncode(sample)) as Map<String,dynamic>;
    (data['questions'] as List)[2]['answer']={'A':'2'};
    expect(()=>ExamImport.parse(jsonEncode(data)),throwsFormatException);
  });
}
