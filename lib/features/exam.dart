import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/design.dart';
import '../core/g2_monitor.dart';
import '../data/grading.dart';
import '../data/models.dart';
import '../main.dart';
import '../widgets/rich_math.dart';

Future<void> openExam(BuildContext context, EduState state, Exam exam) async {
  if (!state.repo.isDemo && state.repo.user==null) {
    showError(context,'Đăng nhập để làm bài và đồng bộ điểm thi.');return;
  }
  await pushScreen<void>(context,ExamIntroPage(state:state,exam:exam));
}

class ExamIntroPage extends StatefulWidget {
  const ExamIntroPage({super.key,required this.state,required this.exam});
  final EduState state;
  final Exam exam;
  @override
  State<ExamIntroPage> createState()=>_ExamIntroPageState();
}
class _ExamIntroPageState extends State<ExamIntroPage> {
  bool agreed=false;
  @override
  Widget build(BuildContext context) => PageWrap(title:'Trước khi bắt đầu',child:ListView(padding:const EdgeInsets.all(20),children:[
    const SizedBox(height:10),Text(widget.exam.title,style:Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height:7),Text('${widget.exam.subject} · ${widget.exam.minutes} phút · ${widget.exam.questionCount} câu',style:const TextStyle(color:Palette.muted)),
    const SizedBox(height:16),const Surface(color:Color(0xFFE9F0FF),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Icon(Icons.shield_outlined,color:Palette.blue),SizedBox(width:9),Text('Quy định phòng thi G2',style:TextStyle(fontWeight:FontWeight.w800,fontSize:16))]),
      SizedBox(height:10),Text('Khi thoát ứng dụng, chuyển sang đa nhiệm hoặc tắt màn hình, sự cố có thể được ghi nhận và trừ 1 điểm trên thang 10. Các tín hiệu gần nhau được gộp để hạn chế phạt trùng.'),
      SizedBox(height:8),Text('Lịch sử được lưu để phúc tra. Sự cố hệ thống hoặc cuộc gọi khẩn có thể yêu cầu miễn trừ.',style:TextStyle(color:Palette.muted)),
    ])),
    const SizedBox(height:12),Surface(child:Column(children:[
      const ListTile(leading:Icon(Icons.timer_outlined,color:Palette.blue),title:Text('Đồng hồ làm bài'),subtitle:Text('Thời gian tiếp tục trôi khi bạn rời ứng dụng.')),
      const Divider(height:1),
      const ListTile(leading:Icon(Icons.save_outlined,color:Palette.blue),title:Text('Lưu bài nháp'),subtitle:Text('Câu trả lời được lưu trên thiết bị. Hãy nộp bài trước khi hết giờ.')),
      const Divider(height:1),
      const ListTile(leading:Icon(Icons.fact_check_outlined,color:Palette.blue),title:Text('Đáp án và lời giải'),subtitle:Text('Được hiển thị sau khi hoàn thành bài thi.')),
    ])),
    const SizedBox(height:14),CheckboxListTile(
      value:agreed,onChanged:(value)=>setState(()=>agreed=value??false),controlAffinity:ListTileControlAffinity.leading,
      title:const Text('Tôi đã đọc và đồng ý quy định G2.',style:TextStyle(fontWeight:FontWeight.w700,fontSize:14))),
    const SizedBox(height:10),ElevatedButton.icon(
      onPressed:agreed?()=>Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>ExamPage(state:widget.state,exam:widget.exam))):null,
      icon:const Icon(Icons.play_arrow),label:const Text('Bắt đầu làm bài')),
  ]));
}

class ExamPage extends StatefulWidget {
  const ExamPage({super.key,required this.state,required this.exam});
  final EduState state;
  final Exam exam;
  @override
  State<ExamPage> createState()=>_ExamPageState();
}
class _ExamPageState extends State<ExamPage> {
  List<ExamQuestion> questions=[];
  Map<String,dynamic> answers={};
  final Set<String> flagged={};
  final List<G2Incident> unsynced=[];
  late final G2Monitor monitor=G2Monitor(_onIncident);
  String? sessionId,error;
  DateTime? startTime;
  Timer? timer, draftTimer;
  int current=0,remaining=0;
  bool loading=true,submitting=false;

  @override
  void initState(){super.initState();unawaited(_begin());}
  Future<void> _begin() async {
    try {
      final qs=await widget.state.repo.questions(widget.exam);
      final session=await widget.state.repo.startExam(widget.exam.id);
      final info=await widget.state.repo.sessionInfo(session);
      final local=await widget.state.repo.readDraft(widget.exam.id,session);
      final saved={...info.$2,...local};
      if(!mounted)return;
      setState((){questions=qs;answers=saved;sessionId=session;remaining=(widget.exam.minutes*60-DateTime.now().difference(info.$1).inSeconds).clamp(0,widget.exam.minutes*60);startTime=info.$1;loading=false;});
      await monitor.start();
      timer=Timer.periodic(const Duration(seconds:1),(_){
        if(!mounted||submitting)return;
        final seconds=widget.exam.minutes*60-DateTime.now().difference(startTime!).inSeconds;
        setState(()=>remaining=seconds>0?seconds:0);
        if(seconds<=0)unawaited(_submit(auto:true));
      });
    } catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _onIncident(G2Incident incident) async {
    unsynced.add(incident);
    if(mounted)setState((){});
    try {await _flushIncidents(showErrors:false);} catch (_) {/* retry before submission */}
  }
  Future<void> _flushIncidents({required bool showErrors}) async {
    if(sessionId==null)return;
    for(final incident in List<G2Incident>.from(unsynced)) {
      try {
        await widget.state.repo.logIncident(sessionId!,incident.kind,incident.clientKey);
        unsynced.remove(incident);
      } catch(e) {
        if(showErrors&&mounted)showError(context,'Không đồng bộ được sự cố G2: $e');
        rethrow;
      }
    }
  }
  void _setAnswer(dynamic value) {
    answers[questions[current].id]=value;
    setState((){});
    unawaited(widget.state.repo.saveDraft(widget.exam.id,sessionId!,answers));
    draftTimer?.cancel();
    draftTimer=Timer(const Duration(milliseconds:600),(){
      if(sessionId!=null)unawaited(widget.state.repo.syncDraft(sessionId!,Map<String,dynamic>.from(answers)).catchError((_){}));
    });
  }
  Future<void> _submit({bool auto=false}) async {
    if(submitting||sessionId==null||questions.isEmpty)return;
    if(!auto) {
      final accept=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
        title:const Text('Nộp bài thi?'),
        content:Text('Bạn đã trả lời ${answers.entries.where((e)=>!isUnanswered(e.value)).length}/${questions.length} câu. Sau khi nộp sẽ không thể chỉnh sửa.'),
        actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Làm tiếp')),
          FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Nộp bài'))]));
      if(accept!=true)return;
    }
    setState(()=>submitting=true);
    try {
      await monitor.stop();
      await _flushIncidents(showErrors:true);
      draftTimer?.cancel();
      await widget.state.repo.syncDraft(sessionId!,answers);
      final result=await widget.state.repo.submitExam(widget.exam.id,sessionId!,questions,answers,monitor.incidents.length);
      await widget.state.repo.clearDraft(widget.exam.id);
      timer?.cancel();
      if(!mounted)return;
      Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>ResultPage(exam:widget.exam,result:result,questions:questions,answers:answers)));
    } catch(e) {
      if(mounted){setState(()=>submitting=false);showError(context,'Nộp bài chưa thành công, bạn có thể thử lại: $e');}
      // Re-enable native listener if submitting failed; recorded events remain.
      await monitor.start();
    }
  }
  Future<void> _confirmExit() async {
    final leave=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Rời phòng thi?'),
      content:const Text('Bài đang làm đã được lưu trên thiết bị. Khi quay lại, thời gian và phiên thi trực tuyến có thể tiếp tục trôi.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Ở lại')),
        TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Rời phòng thi'))]));
    if(leave==true&&mounted){draftTimer?.cancel();await monitor.add('app_background');await monitor.stop();if(mounted)Navigator.pop(context);}
  }
  @override
  void dispose(){timer?.cancel();draftTimer?.cancel();unawaited(monitor.stop());super.dispose();}
  @override
  Widget build(BuildContext context) {
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(error!=null)return PageWrap(title:'Không mở được đề',child:Center(child:Padding(padding:const EdgeInsets.all(25),child:Text(error!))));
    final q=questions[current];
    final answered=answers.entries.where((e)=>!isUnanswered(e.value)).length;
    return PopScope(canPop:false,onPopInvokedWithResult:(didPop,result){if(!didPop)unawaited(_confirmExit());},child:Scaffold(
      appBar:AppBar(title:const Text('Phòng thi EduHub'),leading:IconButton(onPressed:_confirmExit,icon:const Icon(Icons.arrow_back)),actions:[
        Padding(padding:const EdgeInsets.only(right:12),child:Center(child:StateTag('${(remaining~/60).toString().padLeft(2,'0')}:${(remaining%60).toString().padLeft(2,'0')}',color:remaining<120?Palette.red:Palette.blue))),
      ]),
      body:SafeArea(child:Column(children:[
        LinearProgressIndicator(value:answered/questions.length,minHeight:5,color:Palette.blue,backgroundColor:Palette.border),
        Expanded(child:ListView(padding:const EdgeInsets.all(16),children:[
          Row(children:[StateTag('Câu ${current+1}/${questions.length}'),const Spacer(),
            if(monitor.incidents.isNotEmpty) StateTag('${monitor.incidents.length} sự cố G2',color:Palette.red),
            IconButton(tooltip:'Đánh dấu câu',onPressed:()=>setState((){flagged.contains(q.id)?flagged.remove(q.id):flagged.add(q.id);}),
              icon:Icon(flagged.contains(q.id)?Icons.flag:Icons.outlined_flag,color:flagged.contains(q.id)?Palette.amber:Palette.muted)),
          ]),
          const SizedBox(height:14),Surface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            RichMathText(q.prompt,fontSize:17,weight:FontWeight.w600),
            if(q.imageUrl.isNotEmpty) ...[const SizedBox(height:12),ExamFigure(q.imageUrl)],const SizedBox(height:14),
            QuestionAnswerEditor(key:ValueKey(q.id),question:q,value:answers[q.id],onChanged:_setAnswer),
          ])),
          const SizedBox(height:16),Surface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Đi đến câu',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:8),
            Wrap(spacing:8,runSpacing:8,children:List.generate(questions.length,(i){
              final selected=i==current,hasAnswer=!isUnanswered(answers[questions[i].id]);
              return SizedBox(width:42,height:39,child:OutlinedButton(
                style:OutlinedButton.styleFrom(padding:EdgeInsets.zero,backgroundColor:selected?Palette.blue:hasAnswer?const Color(0xFFE8F7F0):Colors.white,
                  foregroundColor:selected?Colors.white:Palette.ink,side:BorderSide(color:selected?Palette.blue:Palette.border)),
                onPressed:()=>setState(()=>current=i),child:Text('${i+1}'),
              ));
            })),
          ])),
          const SizedBox(height:20),
        ])),
        Container(color:Colors.white,padding:const EdgeInsets.fromLTRB(16,10,16,14),child:Row(children:[
          OutlinedButton(onPressed:current==0?null:()=>setState(()=>current--),child:const Text('Câu trước')),
          const Spacer(),if(current<questions.length-1) ElevatedButton(
            onPressed:()=>setState(()=>current++),style:ElevatedButton.styleFrom(minimumSize:const Size(138,48)),child:const Text('Câu tiếp'))
          else ElevatedButton(onPressed:submitting?null:()=>_submit(),style:ElevatedButton.styleFrom(minimumSize:const Size(145,48)),child:Text(submitting?'Đang nộp...':'Nộp bài')),
        ])),
      ])),
    ));
  }
}

class QuestionAnswerEditor extends StatelessWidget {
  const QuestionAnswerEditor({super.key,required this.question,required this.value,required this.onChanged});
  final ExamQuestion question;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  @override
  Widget build(BuildContext context) {
    switch(question.kind) {
      case 'single':
      case 'multiple':
        return Column(children:List.generate(question.options.length,(i){
          final letter=String.fromCharCode(65+i);
          final active=question.kind=='single'?value==letter:asList(value).contains(letter);
          return Padding(padding:const EdgeInsets.only(bottom:9),child:Surface(
            color:active?const Color(0xFFE8F0FF):Palette.canvas,
            onTap:(){if(question.kind=='single')onChanged(letter);else {
              final picked=List<String>.from(asList(value).map((e)=>e.toString()));
              picked.contains(letter)?picked.remove(letter):picked.add(letter);
              onChanged(picked);
            }},
            child:Row(children:[
              CircleAvatar(radius:16,backgroundColor:active?Palette.blue:Colors.white,child:Text(letter,style:TextStyle(color:active?Colors.white:Palette.blue,fontWeight:FontWeight.bold))),
              const SizedBox(width:10),Expanded(child:RichMathText(question.options[i])),
              Icon(question.kind=='single'?(active?Icons.radio_button_checked:Icons.radio_button_off):(active?Icons.check_box:Icons.check_box_outline_blank),color:active?Palette.blue:Palette.muted,size:21),
            ]),
          ));
        }));
      case 'true_false':
        final values=List<dynamic>.from(asList(value));
        while(values.length<question.statements.length){values.add(null);}
        return Column(children:List.generate(question.statements.length,(i)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Surface(color:Palette.canvas,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[StateTag(String.fromCharCode(97+i)),const SizedBox(width:8),Expanded(child:RichMathText(question.statements[i]))]),
          const SizedBox(height:8),Row(children:[for(final choice in [true,false])Expanded(child:Padding(padding:const EdgeInsets.only(right:8),child:OutlinedButton(
            style:OutlinedButton.styleFrom(backgroundColor:values[i]==choice?(choice?const Color(0xFFE3F9EB):const Color(0xFFFFE9E9)):Colors.white),
            onPressed:(){final next=List<dynamic>.from(values);next[i]=choice;onChanged(next);},child:Text(choice?'Đúng':'Sai',style:TextStyle(color:choice?Palette.green:Palette.red,fontWeight:FontWeight.w700)),
          )))]),
        ])))));
      case 'short':
      case 'essay':
        return TextFormField(key:ValueKey('${question.id}-input'),initialValue:asText(value),maxLines:question.kind=='essay'?7:1,
          keyboardType:question.kind=='short'?TextInputType.text:TextInputType.multiline,
          decoration:InputDecoration(labelText:question.kind=='essay'?'Bài làm của bạn':'Nhập đáp án',hintText:question.kind=='short'?'Ví dụ: 2,5':'Trình bày lời giải...'),
          onChanged:onChanged);
      case 'matching':
        final actual=asMap(value);
        return Column(children:question.pairs.map((entry){
          final left=entry['left']??'';
          final id=entry['label']??left;
          final selected=actual[id]?.toString();
          return Padding(padding:const EdgeInsets.only(bottom:12),child:Surface(color:Palette.canvas,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            RichMathText('$id. $left'),const SizedBox(height:6),
            DropdownButtonFormField<String>(initialValue:selected,decoration:const InputDecoration(labelText:'Ghép với'),
              items:List.generate(question.options.length,(i)=>DropdownMenuItem(value:'${i+1}',child:Text('${i+1}. ${question.options[i]}'))),
              onChanged:(choice){final next=Map<String,dynamic>.from(actual);next[id]=choice;onChanged(next);}),
          ])));
        }).toList());
      default: return const Text('Dạng câu hỏi không được hỗ trợ.');
    }
  }
}

class ResultPage extends StatelessWidget {
  const ResultPage({super.key,required this.exam,required this.result,required this.questions,required this.answers});
  final Exam exam;
  final ExamResult result;
  final List<ExamQuestion> questions;
  final Map<String,dynamic> answers;
  @override
  Widget build(BuildContext context)=>PageWrap(title:'Hoàn thành bài thi',child:ListView(padding:const EdgeInsets.all(18),children:[
    const SizedBox(height:20),Surface(child:Column(children:[
      const Text('HOÀN THÀNH BÀI THI',style:TextStyle(color:Palette.blue,fontWeight:FontWeight.w800,letterSpacing:1)),
      const SizedBox(height:14),const Text('Chúc mừng bạn đã\nhoàn thành bài thi!',textAlign:TextAlign.center,style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:Palette.ink)),
      const SizedBox(height:13),const Text('Bài làm đã được ghi nhận. Các chỉ số bên dưới được tính theo số câu hỏi.',textAlign:TextAlign.center,style:TextStyle(color:Palette.muted)),
      const SizedBox(height:20),
      Wrap(spacing:8,runSpacing:8,children:[
        _Metric('Tổng số câu',questions.length.toString()),_Metric('Đúng',result.correct.toString(),color:Palette.green),
        _Metric('Sai',result.wrong.toString(),color:Palette.red),_Metric('Bỏ qua',result.skipped.toString(),color:Palette.amber),
        if(result.pending>0)_Metric('Chờ chấm',result.pending.toString(),color:Palette.purple),
      ]),
      const SizedBox(height:25),Row(children:[
        Expanded(child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFEDF2FF),borderRadius:BorderRadius.circular(13)),child:Column(children:[
          const Text('ĐIỂM HỌC THUẬT',style:TextStyle(color:Palette.muted,fontSize:11,fontWeight:FontWeight.w800)),
          const SizedBox(height:8),Text(result.academicScore.toStringAsFixed(2),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:28)),
        ]))),const SizedBox(width:9),Expanded(child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFE8F7EA),borderRadius:BorderRadius.circular(13)),child:Column(children:[
          const Text('ĐIỂM CUỐI G2',style:TextStyle(color:Palette.muted,fontSize:11,fontWeight:FontWeight.w800)),
          const SizedBox(height:8),Text(result.finalScore.toStringAsFixed(2),style:const TextStyle(color:Palette.green,fontWeight:FontWeight.w900,fontSize:28)),
        ]))),
      ]),
      const SizedBox(height:12),if(result.penalties>0)Text('G2: ${result.penalties} sự cố hợp lệ, trừ ${result.penalties} điểm. Có thể yêu cầu phúc tra.',textAlign:TextAlign.center,style:const TextStyle(color:Palette.red)),
      if(result.pending>0) const Padding(padding:EdgeInsets.only(top:8),child:Text('Điểm tạm tính: còn bài tự luận đang chờ giáo viên chấm.',textAlign:TextAlign.center,style:TextStyle(color:Palette.purple))),
      const SizedBox(height:24),ElevatedButton(onPressed:()=>pushScreen(context,ReviewPage(result:result,questions:questions,answers:answers)),child:const Text('Xem đáp án và lời giải')),
      const SizedBox(height:10),OutlinedButton(onPressed:()=>Navigator.pop(context),child:const Text('Về trang trước')),
    ])),
  ]));
}
class _Metric extends StatelessWidget {
  const _Metric(this.label,this.value,{this.color=Palette.ink});
  final String label,value;final Color color;
  @override
  Widget build(BuildContext context)=>Container(width:135,padding:const EdgeInsets.symmetric(vertical:12,horizontal:8),decoration:BoxDecoration(color:Palette.canvas,borderRadius:BorderRadius.circular(12)),child:Column(children:[Text(label,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:Palette.muted)),const SizedBox(height:8),Text(value,style:TextStyle(fontSize:21,fontWeight:FontWeight.w800,color:color))]));
}

class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key,required this.result,required this.questions,required this.answers});
  final ExamResult result;
  final List<ExamQuestion> questions;
  final Map<String,dynamic> answers;
  @override
  Widget build(BuildContext context)=>PageWrap(title:'Xem đáp án',actions:[Padding(padding:const EdgeInsets.only(right:14),child:Center(child:StateTag('${result.correct}/${questions.length}')))],child:ListView(padding:const EdgeInsets.all(16),children:[
    ...questions.map((q){
      final info=asMap(result.details[q.id]);
      final status=asText(info['status'],'unknown');
      final answer=info.containsKey('answer')?info['answer']:q.answer;
      final explanation=asText(info['explanation'],q.explanation);
      final chosen=info.containsKey('chosen')?info['chosen']:answers[q.id];
      final color=status=='correct'?Palette.green:status=='wrong'?Palette.red:status=='pending'?Palette.purple:Palette.muted;
      return Padding(padding:const EdgeInsets.only(bottom:14),child:Surface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        StateTag('Câu ${q.position} · ${switch(status){'correct'=>'Đúng','wrong'=>'Sai','pending'=>'Chờ chấm','skipped'=>'Bỏ qua',_=>'Đã nộp'}}',color:color),
        const SizedBox(height:12),RichMathText(q.prompt,fontSize:16),
        if(q.imageUrl.isNotEmpty)ExamFigure(q.imageUrl),
        const SizedBox(height:13),
        if(q.options.isNotEmpty) ...q.options.asMap().entries.map((entry)=>Padding(padding:const EdgeInsets.only(bottom:5),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${String.fromCharCode(65+entry.key)}. ',style:const TextStyle(fontWeight:FontWeight.bold)),Expanded(child:RichMathText(entry.value)),
        ]))),
        if(q.statements.isNotEmpty) ...q.statements.asMap().entries.map((entry)=>Padding(padding:const EdgeInsets.only(bottom:4),child:RichMathText('${String.fromCharCode(97+entry.key)}. ${entry.value}'))),
        const Divider(height:22),
        Text('Đáp án của bạn: ${_answerLabel(chosen)}',style:const TextStyle(color:Palette.blue,fontWeight:FontWeight.w700)),
        if(status!='pending') ...[const SizedBox(height:6),Text('Đáp án đúng: ${_answerLabel(answer)}',style:const TextStyle(color:Palette.green,fontWeight:FontWeight.w700))],
        if(explanation.isNotEmpty) ...[const SizedBox(height:9),RichMathText('Lời giải: $explanation')],
      ])));
    }),
  ]));
}
String _answerLabel(dynamic v) {
  if(v==null)return 'Chưa có';
  if(v is List)return v.map((e)=>e==true?'Đúng':e==false?'Sai':e.toString()).join(' · ');
  if(v is Map)return v.entries.map((e)=>'${e.key}: ${e.value}').join(' · ');
  return v.toString();
}

class ExamFigure extends StatelessWidget {
  const ExamFigure(this.url,{super.key});
  final String url;
  @override
  Widget build(BuildContext context) {
    if(!url.startsWith('https://'))return const SizedBox.shrink();
    return Padding(padding:const EdgeInsets.symmetric(vertical:10),child:ClipRRect(
      borderRadius:BorderRadius.circular(8),child:Image.network(url,
        fit:BoxFit.contain,height:220,width:double.infinity,
        loadingBuilder:(context,child,loading)=>loading==null?child:const SizedBox(height:120,child:Center(child:CircularProgressIndicator())),
        errorBuilder:(context,error,stack)=>const Padding(padding:EdgeInsets.all(12),child:Text('Không tải được hình minh họa. Kiểm tra kết nối và đường dẫn ảnh.')),
      ),
    ));
  }
}
