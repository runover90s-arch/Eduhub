import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/design.dart';
import '../data/models.dart';
import '../data/import_validation.dart';
import '../main.dart';
import '../widgets/rich_math.dart';
import 'exam.dart' show ExamFigure;

class StudioPage extends StatefulWidget {
  const StudioPage({super.key,required this.state});
  final EduState state;
  @override
  State<StudioPage> createState()=>_StudioPageState();
}
class _StudioPageState extends State<StudioPage> {
  int tab=0;
  @override
  Widget build(BuildContext context) {
    if(!widget.state.repo.isAdmin)return const PageWrap(title:'EduHub Studio',child:Center(child:Text('Chỉ tài khoản quản trị có quyền truy cập.')));
    final repo=widget.state.repo;
    return PageWrap(title:'EduHub Studio',child:Column(children:[
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:List.generate(4,(i)=>Padding(padding:const EdgeInsets.symmetric(horizontal:4),child:ChoiceChip(
        label:Text(['Đề thi','Bài học','Gói đăng ký','Giám sát G2'][i]),selected:tab==i,onSelected:(_)=>setState(()=>tab=i),
      ))))),
      Expanded(child:switch(tab){
        0=>_examPanel(context),1=>_lessonPanel(context),2=>_ordersPanel(context),_=>_incidentPanel(context)
      }),
    ]));
  }

  Widget _examPanel(BuildContext context) {
    final repo=widget.state.repo;
    return FutureBuilder(future:repo.adminExams(),builder:(ctx,s){
      return ListView(padding:const EdgeInsets.all(16),children:[
        OutlinedButton.icon(onPressed:()async{
          final imported=await pushScreen<bool>(context,ExamImportPage(state:widget.state));
          if(imported==true&&mounted)setState((){});
        },icon:const Icon(Icons.data_object),label:const Text('Nhập đề hàng loạt (JSON)')),
        const SizedBox(height:9),
        ElevatedButton.icon(onPressed:()async{
          final saved=await pushScreen<bool>(context,ExamCreatePage(state:widget.state));
          if(saved==true&&mounted)setState((){});
        },icon:const Icon(Icons.add),label:const Text('Tạo đề mới')),
        const SectionHeading('Danh sách đề'),
        if(s.hasError)Text('${s.error}') else if(!s.hasData)const Center(child:CircularProgressIndicator())
        else ...s.data!.map((row)=>Padding(padding:const EdgeInsets.only(bottom:9),child:Surface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(asText(row['title']),style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:6),
          Row(children:[StateTag(asText(row['status'])),const Spacer(),
            if(asText(row['status'])=='draft') TextButton(onPressed:()async{
              await pushScreen(context,QuestionCreatePage(state:widget.state,examId:asText(row['id'])));if(mounted)setState((){});
            },child:const Text('Thêm câu')),
            TextButton(onPressed:()async{
              try{if(row['status']=='published')await repo.archiveExam(asText(row['id']));else await repo.publishExam(asText(row['id']));
                if(mounted)setState((){});
              }catch(e){showError(context,e);}
            },child:Text(row['status']=='published'?'Lưu trữ':'Công bố')),
          ]),
        ])))),
      ]);
    });
  }
  Widget _lessonPanel(BuildContext context) {
    return ListView(padding:const EdgeInsets.all(16),children:[
      ElevatedButton.icon(onPressed:() async {
        final saved=await pushScreen<bool>(context,LessonCreatePage(state:widget.state));
        if(saved==true&&mounted)setState((){});
      },icon:const Icon(Icons.note_add_outlined),label:const Text('Soạn bài học mới')),
      const SectionHeading('Bài học đã công bố'),
      ...widget.state.lessons.map((lesson)=>Padding(padding:const EdgeInsets.only(bottom:9),child:Surface(child:Row(children:[
        Expanded(child:Text(lesson.title,style:const TextStyle(fontWeight:FontWeight.w700))),
        if(lesson.access=='pro')const StateTag('PRO',color:Palette.purple),
      ])))),
      const Text('Bài học mới được tạo ở trạng thái nháp và chỉ công bố sau khi người quản trị xác nhận.',style:TextStyle(color:Palette.muted)),
    ]);
  }
  Widget _ordersPanel(BuildContext context) {
    final repo=widget.state.repo;
    return FutureBuilder(future:repo.adminOrders(),builder:(ctx,s)=>ListView(padding:const EdgeInsets.all(16),children:[
      ElevatedButton.icon(onPressed:()async{
        final saved=await pushScreen<bool>(context,PackageCreatePage(state:widget.state));
        if(saved==true&&mounted){await widget.state.refresh();setState((){});}
      },icon:const Icon(Icons.add),label:const Text('Tạo gói hoặc combo')),
      const SizedBox(height:12),
      const Surface(color:Color(0xFFE6F0FF),child:Text('Chưa hỗ trợ tự động thanh toán. Chỉ duyệt yêu cầu sau khi bạn đã xác nhận quyền cấp gói bằng quy trình ngoài ứng dụng.')),
      const SectionHeading('Yêu cầu đăng ký gói'),
      if(!s.hasData)const Center(child:CircularProgressIndicator())
      else if(s.data!.isEmpty)const Surface(child:Text('Chưa có yêu cầu đăng ký.'))
      else ...s.data!.map((order)=>Padding(padding:const EdgeInsets.only(bottom:8),child:Surface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Mã đơn: ${order['id']}',style:const TextStyle(fontSize:12)),
        Text('Gói: ${order['package_id']}',style:const TextStyle(fontWeight:FontWeight.w700)),
        Text('Trạng thái: ${order['status']}',style:const TextStyle(color:Palette.muted)),
        if(order['status']=='pending')TextButton(onPressed:()async{
          final accept=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Cấp quyền thủ công?'),
            content:const Text('Chỉ xác nhận khi đã tự xác minh yêu cầu qua kênh hỗ trợ. Bước này không xử lý thanh toán.'),
            actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Hủy')),
              FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Cấp quyền'))]));
          if(accept!=true)return;
          try{await repo.approveOrder(asText(order['id']));if(mounted)setState((){});}catch(e){showError(context,e);}
        },child:const Text('Duyệt và cấp quyền')),
      ])))),
    ]));
  }
  Widget _incidentPanel(BuildContext context) {
    final repo=widget.state.repo;
    return FutureBuilder(future:repo.adminIncidents(),builder:(ctx,s)=>ListView(padding:const EdgeInsets.all(16),children:[
      const Surface(child:Text('Mọi sự cố G2 là tín hiệu hệ thống, không đủ để kết luận người học gian lận. Có thể miễn trừ và tính lại điểm.')),
      const SectionHeading('Nhật ký G2 gần đây'),
      if(!s.hasData)const Center(child:CircularProgressIndicator())
      else ...s.data!.map((entry)=>Padding(padding:const EdgeInsets.only(bottom:9),child:Surface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('${entry['kind']} · ${entry['created_at']}',style:const TextStyle(fontWeight:FontWeight.w700)),
        Text('Phiên thi: ${entry['session_id']}',style:const TextStyle(color:Palette.muted,fontSize:12)),
        if(entry['waived_reason'] != null) Text('Đã miễn trừ: ${entry['waived_reason']}',style:const TextStyle(color:Palette.green))
        else TextButton(onPressed:()async{
          final ctl=TextEditingController();
          final reason=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Lý do miễn trừ'),
            content:TextField(controller:ctl,maxLines:3,decoration:const InputDecoration(hintText:'Nêu lý do phúc tra...')),
            actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Hủy')),
              FilledButton(onPressed:()=>Navigator.pop(ctx,ctl.text),child:const Text('Miễn trừ'))]));
          ctl.dispose();if(reason==null||reason.trim().length<5){showError(context,'Lý do cần ít nhất 5 ký tự.');return;}
          try{await repo.waiveIncident(asText(entry['id']),reason);if(mounted)setState((){});}catch(e){showError(context,e);}
        },child:const Text('Phúc tra / miễn trừ')),
      ])))),
      const SectionHeading('Bài tự luận chờ chấm'),
      FutureBuilder(future:repo.pendingEssays(),builder:(ctx,s2){
        if(!s2.hasData)return const Center(child:CircularProgressIndicator());
        if(s2.data!.isEmpty)return const Text('Không có bài tự luận chờ chấm.');
        return Column(children:s2.data!.map((attempt){
          final details=asMap(attempt['details']);
          final pending=details.entries.where((e)=>asMap(e.value)['status']=='pending').toList();
          return Column(children:pending.map((entry)=>Surface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Phiên: ${attempt['session_id']}',style:const TextStyle(fontSize:11,color:Palette.muted)),
            RichMathText(asText(asMap(entry.value)['prompt'])),
            const SizedBox(height:5),Text('Bài làm: ${asMap(entry.value)['chosen']}',style:const TextStyle(color:Palette.blue)),
            TextButton(onPressed:()async{
              final ctl=TextEditingController();
              final value=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Điểm cho câu tự luận'),
                content:TextField(controller:ctl,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Điểm đạt (không quá điểm tối đa của câu)')),
                actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Hủy')),
                  FilledButton(onPressed:()=>Navigator.pop(ctx,ctl.text),child:const Text('Chấm'))]));
              ctl.dispose();if(value==null)return;
              final number=double.tryParse(value.replaceAll(',','.'));
              if(number==null||number<0){showError(context,'Điểm không hợp lệ.');return;}
              try{await repo.gradeEssay(asText(attempt['session_id']),entry.key,number);if(mounted)setState((){});}catch(e){showError(context,e);}
            },child:const Text('Chấm điểm')),
          ]))).toList());
        }).toList());
      }),
    ]));
  }
}

class ExamImportPage extends StatefulWidget {
  const ExamImportPage({super.key,required this.state});
  final EduState state;
  @override
  State<ExamImportPage> createState()=>_ExamImportPageState();
}
class _ExamImportPageState extends State<ExamImportPage> {
  final input=TextEditingController();
  ExamImport? draft;
  String? error;
  bool importing=false;
  int uploaded=0;
  @override
  void dispose(){input.dispose();super.dispose();}
  void _validate(){
    try{final parsed=ExamImport.parse(input.text);setState((){draft=parsed;error=null;});}
    catch(e){setState((){draft=null;error=e.toString();});}
  }
  Future<void> _import() async {
    final parsed=draft;if(parsed==null)return;
    final confirm=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Nhập bản nháp?'),
      content:Text('Đề "${parsed.metadata['title']}" gồm ${parsed.questions.length} câu sẽ được tạo ở trạng thái NHÁP. Cần kiểm tra đáp án trước khi công bố.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Hủy')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Nhập đề'))]));
    if(confirm!=true)return;
    setState((){importing=true;uploaded=0;});
    try {
      final id=await widget.state.repo.createExam(parsed.metadata);
      for(final item in parsed.questions){
        await widget.state.repo.addQuestion(id,{
          'position':item['position'],'kind':item['kind'],'prompt':item['prompt'],
          'options':item['options'],'statements':item['statements'],
          'pairs':item['pairs'],'points':item['points'],'image_url':item['image_url'],
        },item['answer'],asText(item['explanation']));
        if(mounted)setState(()=>uploaded++);
      }
      await widget.state.refresh();
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Đã nhập $uploaded câu. Đề đang ở trạng thái nháp.')));
      Navigator.pop(context,true);
    }catch(e){
      if(mounted)showError(context,'Nhập chưa hoàn chỉnh ở câu ${uploaded+1}: $e. Bản nháp chưa được công bố; kiểm tra trong Studio.');
    }finally{if(mounted)setState(()=>importing=false);}
  }
  @override
  Widget build(BuildContext context)=>PageWrap(title:'Nhập đề JSON',child:ListView(padding:const EdgeInsets.all(17),children:[
    const Surface(color:Color(0xFFEAF0FF),child:Text('Dán JSON đã chuẩn bị từ PDF/Word hoặc ngân hàng đề. Ứng dụng KHÔNG tự trích xuất PDF. Đề sẽ ở trạng thái nháp cho đến khi quản trị viên rà soát và công bố.')),
    const SizedBox(height:11),
    TextField(controller:input,maxLines:17,minLines:10,enabled:!importing,
      decoration:const InputDecoration(labelText:'Nội dung JSON',alignLabelWithHint:true,hintText:'{"title":"Đề ôn tập Toán 12", "subject":"Toán học", "questions":[...]}')),
    const SizedBox(height:12),OutlinedButton(onPressed:importing?null:_validate,child:const Text('Kiểm tra cấu trúc và đáp án')),
    if(error!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(error!,style:const TextStyle(color:Palette.red))),
    if(draft!=null)...[
      const SectionHeading('Bản xem trước'),
      Surface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(asText(draft!.metadata['title']),style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17)),
        Text('${draft!.questions.length} câu · ${draft!.metadata['subject']} · ${draft!.metadata['duration_minutes']} phút'),
        const Divider(),
        ...draft!.questions.take(3).map((q)=>Padding(padding:const EdgeInsets.only(bottom:8),child:RichMathText('Câu ${q['position']}. ${q['prompt']}'))),
      ])),
      const SizedBox(height:14),ElevatedButton(onPressed:importing?null:_import,child:Text(importing?'Đang nhập $uploaded/${draft!.questions.length} câu...':'Tạo bản nháp từ JSON')),
    ],
  ]));
}

class ExamCreatePage extends StatefulWidget {
  const ExamCreatePage({super.key,required this.state});
  final EduState state;
  @override
  State<ExamCreatePage> createState()=>_ExamCreatePageState();
}
class _ExamCreatePageState extends State<ExamCreatePage> {
  final title=TextEditingController(),description=TextEditingController(),minutes=TextEditingController(text:'45');
  String subject='Toán học',access='free';
  bool busy=false;
  @override
  void dispose(){title.dispose();description.dispose();minutes.dispose();super.dispose();}
  Future<void> _create() async {
    if(title.text.trim().length<4){showError(context,'Tên đề ít nhất 4 ký tự.');return;}
    setState(()=>busy=true);
    try {
      final id=await widget.state.repo.createExam({'title':title.text.trim(),'description':description.text.trim(),
        'subject':subject,'grade':12,'duration_minutes':int.tryParse(minutes.text)??45,
        'access_level':access,'difficulty':'Trung bình'});
      if(!mounted)return;
      await pushScreen(context,QuestionCreatePage(state:widget.state,examId:id));
      if(mounted)Navigator.pop(context,true);
    }catch(e){showError(context,e);}finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>PageWrap(title:'Tạo đề mới',child:ListView(padding:const EdgeInsets.all(18),children:[
    TextField(controller:title,decoration:const InputDecoration(labelText:'Tên đề thi')),
    const SizedBox(height:12),TextField(controller:description,maxLines:3,decoration:const InputDecoration(labelText:'Mô tả')),const SizedBox(height:12),
    DropdownButtonFormField(initialValue:subject,decoration:const InputDecoration(labelText:'Môn học'),items:['Toán học','Vật lí','Hóa học','Sinh học','Tiếng Anh','Lịch sử'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>setState(()=>subject=v??subject)),
    const SizedBox(height:12),TextField(controller:minutes,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Thời gian (phút)')),
    const SizedBox(height:12),DropdownButtonFormField(initialValue:access,decoration:const InputDecoration(labelText:'Quyền truy cập'),items:const [DropdownMenuItem(value:'free',child:Text('Miễn phí')),DropdownMenuItem(value:'pro',child:Text('Gói PRO / Combo'))],onChanged:(v)=>setState(()=>access=v??access)),
    const SizedBox(height:20),ElevatedButton(onPressed:busy?null:_create,child:Text(busy?'Đang tạo...':'Tạo bản nháp và thêm câu')),
  ]));
}

class QuestionCreatePage extends StatefulWidget {
  const QuestionCreatePage({super.key,required this.state,required this.examId});
  final EduState state;final String examId;
  @override
  State<QuestionCreatePage> createState()=>_QuestionCreatePageState();
}
class _QuestionCreatePageState extends State<QuestionCreatePage> {
  final prompt=TextEditingController(), options=TextEditingController(), statements=TextEditingController(), answer=TextEditingController(), explanation=TextEditingController(), image=TextEditingController();
  String kind='single';int position=1;bool busy=false;
  @override
  void dispose(){for(final ctrl in [prompt,options,statements,answer,explanation,image]){ctrl.dispose();}super.dispose();}
  dynamic _answer() {
    final raw=answer.text.trim();
    if(kind=='true_false'||kind=='multiple'){
      final parsed=jsonDecode(raw);
      if(parsed is! List)throw const FormatException('Đáp án phải là mảng JSON.');
      return parsed;
    }
    if(kind=='matching'){
      final parsed=jsonDecode(raw);
      if(parsed is! Map)throw const FormatException('Đáp án nối cặp phải là đối tượng JSON.');
      return parsed;
    }
    return kind=='essay'?null:raw;
  }
  Future<void> _save() async {
    if(prompt.text.trim().length<4){showError(context,'Nội dung câu hỏi quá ngắn.');return;}
    setState(()=>busy=true);
    try {
      final ops=options.text.split('\n').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList();
      final sts=statements.text.split('\n').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList();
      if(['single','multiple'].contains(kind)&&ops.length<2)throw const FormatException('Ít nhất hai phương án.');
      if(kind=='true_false'&&sts.isEmpty)throw const FormatException('Cần các phát biểu đúng/sai.');
      if(image.text.trim().isNotEmpty&&!image.text.trim().startsWith('https://'))throw const FormatException('Chỉ nhận liên kết hình HTTPS.');
      if(kind!='essay'&&answer.text.trim().isEmpty)throw const FormatException('Chưa có đáp án.');
      final pairs=<Map<String,String>>[];
      if(kind=='matching')for(var i=0;i<sts.length;i++){pairs.add({'label':String.fromCharCode(65+i),'left':sts[i]});}
      await widget.state.repo.addQuestion(widget.examId,{
        'position':position,'kind':kind,'prompt':prompt.text.trim(),'options':ops,
        'statements':kind=='true_false'?sts:[],'pairs':pairs,'points':kind=='essay'?2:1,'image_url':image.text.trim(),
      },_answer(),explanation.text.trim());
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Đã lưu câu $position.')));
      setState((){position++;prompt.clear();options.clear();statements.clear();answer.clear();explanation.clear();image.clear();});
    }catch(e){showError(context,e);}finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>PageWrap(title:'Soạn câu $position',child:ListView(padding:const EdgeInsets.all(18),children:[
    const Surface(color:Color(0xFFE9F1FF),child:Text(r'LaTeX: gõ $\frac{a}{b}$, $$\int_0^1 x\,dx$$ hoặc \(x^2\). Công thức được xem trước phía dưới.')),
    const SizedBox(height:12),DropdownButtonFormField(initialValue:kind,decoration:const InputDecoration(labelText:'Dạng câu hỏi'),
      items:const [DropdownMenuItem(value:'single',child:Text('Trắc nghiệm 1 đáp án')),DropdownMenuItem(value:'multiple',child:Text('Chọn nhiều đáp án')),
      DropdownMenuItem(value:'true_false',child:Text('Đúng / Sai theo ý')),DropdownMenuItem(value:'short',child:Text('Trả lời ngắn')),
      DropdownMenuItem(value:'matching',child:Text('Nối đáp án')),DropdownMenuItem(value:'essay',child:Text('Tự luận'))],
      onChanged:(v)=>setState(()=>kind=v??kind)),const SizedBox(height:12),
    TextField(controller:prompt,maxLines:4,onChanged:(_)=>setState((){}),decoration:const InputDecoration(labelText:'Nội dung câu hỏi')),const SizedBox(height:12),
    TextField(controller:image,onChanged:(_)=>setState((){}),decoration:const InputDecoration(labelText:'Link hình minh họa HTTPS (không bắt buộc)')),const SizedBox(height:12),
    if(['single','multiple','matching'].contains(kind)) ...[
      TextField(controller:options,maxLines:5,onChanged:(_)=>setState((){}),decoration:const InputDecoration(labelText:'Các đáp án (mỗi dòng 1 phương án)')),
      const SizedBox(height:12),
    ],
    if(['true_false','matching'].contains(kind)) ...[
      TextField(controller:statements,maxLines:5,onChanged:(_)=>setState((){}),decoration:InputDecoration(labelText:kind=='matching'?'Vế trái (mỗi dòng một ý)':'Các phát biểu đúng/sai')),
      const SizedBox(height:12),
    ],
    if(kind!='essay') TextField(controller:answer,decoration:InputDecoration(labelText:'Đáp án',hintText:switch(kind){
      'single'=>'A', 'multiple'=>'["A","C"]', 'true_false'=>'[true,false,true,false]','matching'=>'{"A":"2","B":"1"}',_=>'12,5'
    })),
    if(kind!='essay')const SizedBox(height:12),
    TextField(controller:explanation,maxLines:4,onChanged:(_)=>setState((){}),decoration:const InputDecoration(labelText:'Lời giải / hướng dẫn chấm')),const SizedBox(height:12),
    const SectionHeading('Xem trước công thức'),
    Surface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      RichMathText(prompt.text.isEmpty?'Nhập câu hỏi để xem trước':prompt.text,fontSize:16),
      if(image.text.trim().startsWith('https://'))ExamFigure(image.text.trim()),
      ...options.text.split('\n').where((s)=>s.trim().isNotEmpty).take(3).map((e)=>Padding(padding:const EdgeInsets.only(top:5),child:RichMathText(e))),
      if(explanation.text.isNotEmpty) ...[const Divider(),RichMathText(explanation.text)],
    ])),const SizedBox(height:20),ElevatedButton.icon(onPressed:busy?null:_save,icon:const Icon(Icons.save_outlined),label:Text(busy?'Đang lưu...':'Lưu câu và thêm câu tiếp')),
    TextButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Kết thúc biên tập')),
  ]));
}

class LessonCreatePage extends StatefulWidget {
  const LessonCreatePage({super.key,required this.state});final EduState state;
  @override State<LessonCreatePage>createState()=>_LessonCreatePageState();
}
class _LessonCreatePageState extends State<LessonCreatePage> {
  final title=TextEditingController(),description=TextEditingController(),body=TextEditingController();
  String access='free';bool busy=false;
  @override void dispose(){title.dispose();description.dispose();body.dispose();super.dispose();}
  Future<void> _save() async {
    if(title.text.trim().length<4||body.text.trim().length<15){showError(context,'Cần tên bài và nội dung bài học đầy đủ.');return;}
    setState(()=>busy=true);
    try {
      final id=await widget.state.repo.createLesson({'title':title.text.trim(),'description':description.text.trim(),
        'subject':'Toán học','grade':12,'access_level':access,'duration_minutes':15},body.text);
      if(!mounted)return;
      final publish=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Công bố bài học?'),
        content:const Text('Hãy đảm bảo nội dung và công thức đã được kiểm tra trước khi công bố.'),actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Để bản nháp')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Công bố'))]));
      if(publish==true)await widget.state.repo.publishLesson(id);
      await widget.state.refresh();
      if(mounted)Navigator.pop(context,true);
    }catch(e){showError(context,e);}finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>PageWrap(title:'Soạn bài học',child:ListView(padding:const EdgeInsets.all(18),children:[
    TextField(controller:title,decoration:const InputDecoration(labelText:'Tên bài học')),const SizedBox(height:10),
    TextField(controller:description,decoration:const InputDecoration(labelText:'Mô tả')),const SizedBox(height:10),
    DropdownButtonFormField(initialValue:access,decoration:const InputDecoration(labelText:'Quyền truy cập'),items:const [DropdownMenuItem(value:'free',child:Text('Miễn phí')),DropdownMenuItem(value:'pro',child:Text('PRO'))],onChanged:(v)=>setState(()=>access=v??access)),const SizedBox(height:12),
    TextField(controller:body,maxLines:14,onChanged:(_)=>setState((){}),decoration:const InputDecoration(labelText:'Nội dung bài (hỗ trợ LaTeX)')),
    const SectionHeading('Xem trước bài học'),Surface(child:RichMathText(body.text.isEmpty?'Nhập nội dung bài học...':body.text)),
    const SizedBox(height:18),ElevatedButton(onPressed:busy?null:_save,child:Text(busy?'Đang lưu...':'Lưu bài học')),
  ]));
}


class PackageCreatePage extends StatefulWidget {
  const PackageCreatePage({super.key,required this.state});
  final EduState state;
  @override
  State<PackageCreatePage> createState()=>_PackageCreatePageState();
}
class _PackageCreatePageState extends State<PackageCreatePage> {
  final title=TextEditingController(), description=TextEditingController(),
      price=TextEditingController(text:'29000'),days=TextEditingController(text:'30');
  final Set<String> exams={}, lessons={};
  bool combo=false,allPro=false,busy=false;
  @override
  void dispose(){title.dispose();description.dispose();price.dispose();days.dispose();super.dispose();}
  Future<void> _save() async {
    final cost=int.tryParse(price.text),duration=int.tryParse(days.text);
    if(title.text.trim().length<4||cost==null||cost<0||duration==null||duration<1){
      showError(context,'Tên gói, giá và số ngày chưa hợp lệ.');return;
    }
    if(!allPro&&exams.isEmpty&&lessons.isEmpty){showError(context,'Chọn nội dung được mở khóa cho gói.');return;}
    setState(()=>busy=true);
    try{
      await widget.state.repo.createPackage({
        'title':title.text.trim(),'description':description.text.trim(),
        'price_vnd':cost,'duration_days':duration,'is_combo':combo,
        'grants_all_pro':allPro,'is_active':true,
      },exams.toList(),lessons.toList());
      if(mounted)Navigator.pop(context,true);
    }catch(e){showError(context,e);}finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>PageWrap(title:'Tạo gói học',child:ListView(padding:const EdgeInsets.all(18),children:[
    TextField(controller:title,decoration:const InputDecoration(labelText:'Tên gói hoặc combo')),
    const SizedBox(height:10),TextField(controller:description,maxLines:2,decoration:const InputDecoration(labelText:'Mô tả')),
    const SizedBox(height:10),Row(children:[
      Expanded(child:TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Giá (VND)'))),
      const SizedBox(width:8),Expanded(child:TextField(controller:days,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Thời hạn (ngày)'))),
    ]),
    SwitchListTile(title:const Text('Gói combo'),value:combo,onChanged:(v)=>setState(()=>combo=v)),
    SwitchListTile(title:const Text('Mở toàn bộ nội dung PRO'),subtitle:const Text('Nếu tắt, chỉ mở các đề/bài học được chọn bên dưới.'),value:allPro,onChanged:(v)=>setState(()=>allPro=v)),
    const SectionHeading('Đề thi trong gói'),
    ...widget.state.exams.where((e)=>e.access=='pro').map((e)=>CheckboxListTile(
      value:exams.contains(e.id),title:Text(e.title,style:const TextStyle(fontSize:13)),
      onChanged:(v)=>setState(()=>v==true?exams.add(e.id):exams.remove(e.id)),
    )),
    const SectionHeading('Bài học trong gói'),
    ...widget.state.lessons.where((e)=>e.access=='pro').map((e)=>CheckboxListTile(
      value:lessons.contains(e.id),title:Text(e.title,style:const TextStyle(fontSize:13)),
      onChanged:(v)=>setState(()=>v==true?lessons.add(e.id):lessons.remove(e.id)),
    )),
    const SizedBox(height:12),ElevatedButton(onPressed:busy?null:_save,child:Text(busy?'Đang lưu...':'Lưu gói học')),
  ]));
}
