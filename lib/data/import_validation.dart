import 'dart:convert';
import 'models.dart';

/// A reviewed JSON import is always staged as a draft. No importer publishes.
class ExamImport {
  const ExamImport(this.metadata, this.questions);
  final Map<String,dynamic> metadata;
  final List<Map<String,dynamic>> questions;

  static ExamImport parse(String source) {
    if(source.length>2000000)throw const FormatException('Dữ liệu quá lớn (giới hạn 2 MB).');
    final root=asMap(jsonDecode(source));
    final title=asText(root['title']).trim();
    final subject=asText(root['subject']).trim();
    final description=asText(root['description']).trim();
    final duration=asInt(root['duration_minutes'],45);
    final grade=asInt(root['grade'],12);
    final access=asText(root['access_level'],'free');
    if(title.length<4||title.length>180)throw const FormatException('Tên đề cần từ 4 đến 180 ký tự.');
    if(subject.isEmpty||subject.length>90)throw const FormatException('Chưa có môn học hợp lệ.');
    if(description.length>4000)throw const FormatException('Mô tả đề quá dài.');
    if(duration<1||duration>360||grade<1||grade>12)throw const FormatException('Lớp hoặc thời lượng không hợp lệ.');
    if(access!='free'&&access!='pro')throw const FormatException('Quyền truy cập phải là free hoặc pro.');
    if(root['questions'] is! List)throw const FormatException('Thiếu mảng questions.');
    final sourceQuestions=asList(root['questions']);
    if(sourceQuestions.isEmpty||sourceQuestions.length>2000)throw const FormatException('Đề cần 1–2000 câu.');
    final cleaned=<Map<String,dynamic>>[];
    for(var i=0;i<sourceQuestions.length;i++){
      final original=asMap(sourceQuestions[i]);
      final kind=asText(original['kind']);
      final prompt=asText(original['prompt']).trim();
      final options=asList(original['options']).map((e)=>asText(e).trim()).toList();
      final statements=asList(original['statements']).map((e)=>asText(e).trim()).toList();
      final pairs=asList(original['pairs']).map((e)=>asMap(e)).toList();
      final answer=original['answer'];
      final points=asDouble(original['points'],1);
      void reject(String message)=>throw FormatException('Câu ${i+1}: $message');
      if(!const ['single','multiple','true_false','short','matching','essay'].contains(kind))reject('Dạng câu không được hỗ trợ.');
      if(prompt.length<4||prompt.length>15000)reject('Nội dung câu chưa hợp lệ.');
      if(points<=0||points>100)reject('Điểm câu phải lớn hơn 0 và không quá 100.');
      if((kind=='single'||kind=='multiple')&&(options.length<2||options.length>20||options.any((s)=>s.isEmpty)))reject('Các phương án cần 2–20 đáp án không rỗng.');
      bool validLetter(dynamic letter)=>letter is String&&letter.length==1&&letter.codeUnitAt(0)>=65&&letter.codeUnitAt(0)<65+options.length;
      if(kind=='single'&&!validLetter(answer))reject('Đáp án là chữ A, B, C... tương ứng phương án.');
      if(kind=='multiple'){
        if(answer is! List||answer.isEmpty||answer.any((x)=>!validLetter(x))||answer.toSet().length!=answer.length)reject('Đáp án nhiều lựa chọn phải là mảng chữ cái hợp lệ, không trùng.');
      }
      if(kind=='true_false'){
        if(statements.isEmpty||statements.length>20||statements.any((s)=>s.isEmpty))reject('Cần 1–20 phát biểu không rỗng.');
        if(answer is! List||answer.length!=statements.length||answer.any((e)=>e is! bool))reject('Số giá trị đúng/sai phải khớp từng phát biểu.');
      }
      if(kind=='short'&&(answer==null||asText(answer).trim().isEmpty))reject('Chưa có đáp án trả lời ngắn.');
      if(kind=='matching'){
        if(options.length<2||options.any((s)=>s.isEmpty)||pairs.isEmpty||pairs.length>options.length)reject('Cần vế trái và vế phải để nối.');
        if(answer is! Map||answer.length!=pairs.length)reject('Đáp án nối phải là đối tượng JSON đủ các cặp.');
        final labels=<String>{};
        for(final pair in pairs){
          final label=asText(pair['label']);
          if(label.isEmpty||asText(pair['left']).trim().isEmpty||!labels.add(label))reject('Nhãn hoặc nội dung cặp nối không hợp lệ.');
          final index=asInt(answer[label],-1);
          if(index<1||index>options.length)reject('Cặp nối $label phải khớp vị trí vế phải (1, 2...).');
        }
      }
      final imageUrl=asText(original['image_url']);
      if(imageUrl.isNotEmpty && (!imageUrl.startsWith('https://')||imageUrl.length>2048))reject('Hình ảnh phải là liên kết HTTPS hợp lệ.');
      cleaned.add({
        'position':i+1,'kind':kind,'prompt':prompt,'options':options,'statements':statements,
        'pairs':pairs,'points':points,
        'answer':kind=='essay'?null:kind=='short'?asText(answer):answer,
        'explanation':asText(original['explanation']).trim(),'image_url':imageUrl,
      });
    }
    return ExamImport({
      'title':title,'subject':subject,'description':description,'grade':grade,
      'duration_minutes':duration,'access_level':access,
      'difficulty':asText(root['difficulty'],'Trung bình'),
    },cleaned);
  }
}
