import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/design.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../main.dart';
import 'exam.dart';
import 'studio.dart';
import '../widgets/rich_math.dart';

class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key,required this.state,required this.onGoCatalog});
  final EduState state;
  final VoidCallback onGoCatalog;
  @override
  Widget build(BuildContext context)=>Column(children:[
    Container(color:Palette.blue,width:double.infinity,padding:const EdgeInsets.fromLTRB(20,55,20,22),child:const Center(child:Text('Bài làm của tôi',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:21)))),
    Expanded(child:FutureBuilder<List<ExamResult>>(future:state.repo.attemptHistory(),builder:(context,snapshot){
      if(snapshot.hasError)return Center(child:Text('Không tải được lịch sử: ${snapshot.error}'));
      if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
      final rows=snapshot.data!;
      if(rows.isEmpty) { return Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Icon(Icons.assignment_outlined,size:60,color:Palette.blue),const SizedBox(height:12),
        const Text('Chưa có lượt làm bài',style:TextStyle(fontWeight:FontWeight.w800,fontSize:18)),
        const SizedBox(height:10),const Text('Chọn một bài đánh giá và bắt đầu luyện tập.',textAlign:TextAlign.center),
        const SizedBox(height:18),ElevatedButton(onPressed:onGoCatalog,child:const Text('Khám phá đề thi')),
      ]))); }
      final avg=rows.map((e)=>e.finalScore).reduce((a,b)=>a+b)/rows.length;
      return RefreshIndicator(onRefresh:()async{(context as Element).markNeedsBuild();},child:ListView(padding:const EdgeInsets.all(17),children:[
        Surface(color:const Color(0xFFE5EEFF),child:Row(children:[
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Lượt đã hoàn thành',style:TextStyle(color:Palette.muted)),Text('${rows.length}',style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900))])),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Điểm G2 trung bình',style:TextStyle(color:Palette.muted)),Text(avg.toStringAsFixed(2),style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:Palette.blue))])),
        ])),
        const SectionHeading('Lịch sử gần đây'),
        ...rows.map((item){
          final exam=state.exams.where((e)=>e.id==item.examId).firstOrNull;
          return Padding(padding:const EdgeInsets.only(bottom:10),child:Surface(onTap:()=>pushScreen(context,ReviewPage(result:item,questions:exam?.demoQuestions.isNotEmpty==true?exam!.demoQuestions:_questionsFromResult(item),answers:const {})),child:Row(children:[
            const Icon(Icons.assignment_turned_in_outlined,color:Palette.blue),const SizedBox(width:11),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(exam?.title??'Bài đánh giá đã hoàn thành',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800)),
              Text('${item.correct} đúng · ${item.wrong} sai · ${item.skipped} bỏ qua',style:const TextStyle(fontSize:12,color:Palette.muted)),
            ])),Text(item.finalScore.toStringAsFixed(1),style:const TextStyle(color:Palette.blue,fontWeight:FontWeight.w900,fontSize:21)),
          ])));
        }),
        const SizedBox(height:22),
      ]));
    })),
  ]);
}
List<ExamQuestion> _questionsFromResult(ExamResult result)=>result.details.entries.toList().asMap().entries.map((e){
  final row=asMap(e.value.value);
  return ExamQuestion.fromJson({...row,'id':e.value.key,'position':e.key+1,'prompt':asText(row['prompt'],'Nội dung câu hỏi đã lưu'),'kind':asText(row['kind'],'single')});
}).toList();

class AccountTab extends StatefulWidget {
  const AccountTab({super.key,required this.state});
  final EduState state;
  @override
  State<AccountTab> createState()=>_AccountTabState();
}
class _AccountTabState extends State<AccountTab> {
  @override
  Widget build(BuildContext context) {
    final repo=widget.state.repo;
    return Column(children:[
      Container(width:double.infinity,color:Palette.blue,padding:const EdgeInsets.fromLTRB(20,55,20,22),child:const Center(child:Text('Tài khoản',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w800)))),
      Expanded(child:ListView(padding:const EdgeInsets.all(18),children:[
        Surface(onTap:()=>pushScreen(context,AuthPage(repo:repo)),child:Row(children:[
          const CircleAvatar(backgroundColor:Color(0xFFE5EAF2),radius:28,child:Icon(Icons.person,color:Palette.muted,size:30)),const SizedBox(width:14),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(repo.isDemo?'Chế độ trải nghiệm':repo.displayName,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17)),
            Text(repo.user?.email??(repo.isDemo?'Dữ liệu lưu trên thiết bị':'Chạm để đăng nhập / đăng ký'),style:const TextStyle(color:Palette.muted,fontSize:12)),
          ])),const Icon(Icons.chevron_right,color:Palette.muted),
        ])),
        const SectionHeading('Học tập & cá nhân'),
        Surface(child:Column(children:[
          _menu(context,Icons.class_outlined,'Lớp học của tôi',()=>pushScreen(context,ClassesPage(repo:repo,state:widget.state))),
          const Divider(height:1),_menu(context,Icons.emoji_events_outlined,'Bảng xếp hạng',()=>pushScreen(context,LeaderboardPage(state:widget.state))),
          const Divider(height:1),_menu(context,Icons.notifications_outlined,'Thông báo',()=>pushScreen(context,NotificationsPage(repo:repo))),
          const Divider(height:1),_menu(context,Icons.settings_outlined,'Tùy chọn học tập',()=>pushScreen(context,SettingsPage(state:widget.state))),
        ])),
        if(repo.isAdmin) ...[
          const SectionHeading('Quản trị nội dung'),
          Surface(onTap:()=>pushScreen(context,StudioPage(state:widget.state)),child:const Row(children:[
            Icon(Icons.admin_panel_settings_outlined,color:Palette.blue,size:29),SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('EduHub Studio',style:TextStyle(fontWeight:FontWeight.w800)),Text('Đề thi, bài học, gói mua, phúc tra G2',style:TextStyle(color:Palette.muted,fontSize:12))])),
            Icon(Icons.chevron_right,color:Palette.muted),
          ])),
        ],
        const SectionHeading('Thông tin'),
        const Surface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('EduHub 2.0 · Flutter',style:TextStyle(fontWeight:FontWeight.w800)),SizedBox(height:5),
          Text('Ứng dụng học tập và đánh giá kiến thức. Không chứa chức năng AI tạo sinh hoặc cộng tác viên.',style:TextStyle(color:Palette.muted)),
        ])),
        if(!repo.isDemo&&repo.user!=null) ...[
          const SizedBox(height:20),OutlinedButton(onPressed:()async{await repo.signOut();if(context.mounted)setState((){});},child:const Text('Đăng xuất',style:TextStyle(color:Palette.red))),
        ],
      ])),
    ]);
  }
  Widget _menu(BuildContext context,IconData icon,String text,VoidCallback tap)=>ListTile(onTap:tap,leading:Icon(icon,color:Palette.blue),title:Text(text,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600)),trailing:const Icon(Icons.chevron_right,color:Palette.muted));
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key,required this.repo});
  final EduRepository repo;
  @override
  State<AuthPage> createState()=>_AuthPageState();
}
class _AuthPageState extends State<AuthPage> {
  final nameCtrl=TextEditingController(),emailCtrl=TextEditingController(),passCtrl=TextEditingController();
  bool register=false,busy=false;
  @override
  void dispose(){nameCtrl.dispose();emailCtrl.dispose();passCtrl.dispose();super.dispose();}
  Future<void> _submit() async {
    if(emailCtrl.text.trim().isEmpty||passCtrl.text.length<6){showError(context,'Nhập email hợp lệ và mật khẩu từ 6 ký tự.');return;}
    setState(()=>busy=true);
    try {
      if(register) {
        await widget.repo.signUp(nameCtrl.text.trim(),emailCtrl.text.trim(),passCtrl.text);
      } else {
        await widget.repo.signIn(emailCtrl.text.trim(),passCtrl.text);
      }
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(register?'Đã gửi yêu cầu đăng ký. Kiểm tra email xác nhận nếu được bật.':'Đăng nhập thành công.')));
      Navigator.pop(context);
    }catch(e){showError(context,e);}finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>PageWrap(title:register?'Đăng ký':'Đăng nhập',child:ListView(padding:const EdgeInsets.all(24),children:[
    const SizedBox(height:12),const Center(child:CircleAvatar(backgroundColor:Palette.blue,radius:31,child:Icon(Icons.school,color:Colors.white,size:34))),
    const SizedBox(height:20),Text(register?'Tạo tài khoản EduHub':'Chào mừng trở lại',textAlign:TextAlign.center,style:Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height:22),if(register) ...[TextField(controller:nameCtrl,decoration:const InputDecoration(labelText:'Họ và tên')),const SizedBox(height:12)],
    TextField(controller:emailCtrl,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email')),
    const SizedBox(height:12),TextField(controller:passCtrl,obscureText:true,decoration:const InputDecoration(labelText:'Mật khẩu')),
    const SizedBox(height:20),ElevatedButton(onPressed:busy?null:_submit,child:Text(busy?'Đang xử lý...':register?'Đăng ký':'Đăng nhập')),
    TextButton(onPressed:()=>setState(()=>register=!register),child:Text(register?'Đã có tài khoản? Đăng nhập':'Chưa có tài khoản? Đăng ký')),
    if(!register)TextButton(onPressed:()async{
      try {
        await widget.repo.resetPassword(emailCtrl.text.trim());
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Nếu email hợp lệ, hướng dẫn đặt lại mật khẩu sẽ được gửi.')));
      } catch(e) {
        if (context.mounted) showError(context,e);
      }
    },child:const Text('Quên mật khẩu?')),
    if(widget.repo.isDemo) const Padding(padding:EdgeInsets.only(top:18),child:Text('Bạn đang chạy bản demo. Cấu hình Supabase ở GitHub Actions để đăng nhập bằng tài khoản thật.',style:TextStyle(color:Palette.muted),textAlign:TextAlign.center)),
  ]));
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key,required this.repo});
  final EduRepository repo;
  @override
  State<NotificationsPage> createState()=>_NotificationsPageState();
}
class _NotificationsPageState extends State<NotificationsPage> {
  @override
  Widget build(BuildContext context)=>PageWrap(title:'Thông báo',child:FutureBuilder(future:widget.repo.notifications(),builder:(context,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    if(s.data!.isEmpty)return const Center(child:Text('Chưa có thông báo mới.'));
    return ListView(padding:const EdgeInsets.all(17),children:s.data!.map((item)=>Padding(padding:const EdgeInsets.only(bottom:9),child:Surface(onTap:()async{
      await widget.repo.markNotificationRead(asText(item['id']));if(mounted)setState((){});
    },child:Row(children:[Icon(item['is_read']==true?Icons.notifications_none:Icons.notifications_active_outlined,color:Palette.blue),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(asText(item['title']),style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:5),Text(asText(item['body']),style:const TextStyle(color:Palette.muted)),
    ]))])))).toList());
  }));
}

class ClassesPage extends StatefulWidget {
  const ClassesPage({super.key,required this.repo,required this.state});
  final EduRepository repo;
  final EduState state;
  @override
  State<ClassesPage> createState()=>_ClassesPageState();
}
class _ClassesPageState extends State<ClassesPage> {
  Future<void> _action(bool create) async {
    final ctrl=TextEditingController();
    final result=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:Text(create?'Tạo lớp học':'Tham gia lớp'),
      content:TextField(controller:ctrl,decoration:InputDecoration(labelText:create?'Tên lớp':'Mã lớp')),actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Hủy')),
      FilledButton(onPressed:()=>Navigator.pop(ctx,ctrl.text),child:const Text('Xác nhận'))]));
    ctrl.dispose();if(result==null||result.trim().isEmpty)return;
    try {
      if(create) {
        await widget.repo.createClass(result.trim());
      } else {
        await widget.repo.joinClass(result.trim());
      }
      if(mounted) setState((){});
    } catch(e) {
      if(mounted) showError(context,e);
    }
  }
  @override
  Widget build(BuildContext context)=>PageWrap(title:'Lớp học',child:ListView(padding:const EdgeInsets.all(18),children:[
    Row(children:[Expanded(child:OutlinedButton(onPressed:()=>_action(false),child:const Text('Nhập mã lớp'))),
      if(widget.repo.isTeacher)...[const SizedBox(width:8),Expanded(child:OutlinedButton(onPressed:()=>_action(true),child:const Text('Tạo lớp')))]],),
    const SectionHeading('Lớp đã tham gia'),
    if(widget.repo.isDemo) const Surface(child:Text('Kết nối Supabase để tạo hoặc tham gia lớp học trực tuyến.'))
    else FutureBuilder(future:widget.repo.myClasses(),builder:(ctx,s){
      if(!s.hasData)return const Center(child:CircularProgressIndicator());
      if(s.data!.isEmpty)return const Text('Bạn chưa tham gia lớp nào.');
      return Column(children:s.data!.map((row)=>Padding(padding:const EdgeInsets.only(bottom:9),child:Surface(onTap:()=>pushScreen(context,ClassDetailsPage(repo:widget.repo,state:widget.state,info:row)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(asText(row['name']),style:const TextStyle(fontWeight:FontWeight.w800)),Text('Mã lớp: ${row['join_code']}',style:const TextStyle(color:Palette.muted)),
        if(widget.repo.isTeacher&&asText(row['teacher_id'])==widget.repo.user?.id) TextButton(onPressed:()async{
          final exam=await showModalBottomSheet<Exam>(context:context,builder:(c)=>ListView(children:widget.state.exams.map((e)=>ListTile(title:Text(e.title),onTap:()=>Navigator.pop(c,e))).toList()));
          if(exam==null || !context.mounted) return;
          try {
            await widget.repo.assignExam(asText(row['id']),exam.id);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Đã giao đề cho lớp.')));
          } catch(e) {
            if(context.mounted) showError(context,e);
          }
        },child:const Text('Giao đề')),
      ])))).toList());
    }),
  ]));
}

class ClassDetailsPage extends StatefulWidget {
  const ClassDetailsPage({super.key,required this.repo,required this.state,required this.info});
  final EduRepository repo;
  final EduState state;
  final Map<String,dynamic> info;
  @override
  State<ClassDetailsPage> createState()=>_ClassDetailsPageState();
}
class _ClassDetailsPageState extends State<ClassDetailsPage> {
  bool get owner=>widget.repo.isAdmin ||
      asText(widget.info['teacher_id'])==widget.repo.user?.id;
  @override
  Widget build(BuildContext context) {
    final classId=asText(widget.info['id']);
    return PageWrap(title:asText(widget.info['name'],'Lớp học'),child:ListView(padding:const EdgeInsets.all(17),children:[
      Surface(color:const Color(0xFFE8F0FF),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Mã tham gia lớp',style:TextStyle(color:Palette.muted)),
        const SizedBox(height:6),SelectableText(asText(widget.info['join_code']),style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900,color:Palette.blue)),
        const Text('Chia sẻ mã này với học viên của lớp.',style:TextStyle(fontSize:12,color:Palette.muted)),
      ])),
      const SectionHeading('Bài được giao'),
      FutureBuilder(future:widget.repo.classAssignments(classId),builder:(context,s){
        if(s.hasError)return Surface(child:Text('Không tải được bài giao: ${s.error}'));
        if(!s.hasData)return const Center(child:CircularProgressIndicator());
        if(s.data!.isEmpty)return const Surface(child:Text('Giáo viên chưa giao đề cho lớp.'));
        return Column(children:s.data!.map((row){
          final exam=widget.state.exams.where((e)=>e.id==asText(row['exam_id'])).firstOrNull;
          return Padding(padding:const EdgeInsets.only(bottom:9),child:Surface(onTap:exam==null?null:()=>openExam(context,widget.state,exam),child:Row(children:[
            const Icon(Icons.assignment_outlined,color:Palette.blue),const SizedBox(width:11),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(exam?.title??'Đề đã ẩn hoặc bị lưu trữ',style:const TextStyle(fontWeight:FontWeight.w800)),
              if(row['due_at']!=null)Text('Hạn: ${row['due_at']}',style:const TextStyle(fontSize:11,color:Palette.muted)),
            ])),if(exam!=null)const Icon(Icons.chevron_right,color:Palette.muted),
          ])));
        }).toList());
      }),
      if(owner)...[
        const SectionHeading('Thống kê dành cho giáo viên'),
        FutureBuilder(future:widget.repo.classOverview(classId),builder:(ctx,s){
          if(s.hasError)return Surface(child:Text('Lỗi thống kê: ${s.error}'));
          if(!s.hasData)return const Center(child:CircularProgressIndicator());
          if(s.data!.isEmpty)return const Surface(child:Text('Chưa có bài giao hoặc kết quả.'));
          return Column(children:s.data!.map((row)=>Padding(padding:const EdgeInsets.only(bottom:9),child:Surface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(asText(row['exam_title']),style:const TextStyle(fontWeight:FontWeight.w800)),
            const SizedBox(height:8),Text('Học viên: ${row['learner_count']} · Đã nộp: ${row['submitted_count']}'),
            Text('Điểm G2 trung bình: ${asDouble(row['average_score']).toStringAsFixed(2)}',style:const TextStyle(color:Palette.blue)),
          ])))).toList());
        }),
      ],
    ]));
  }
}

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key,required this.state});
  final EduState state;
  @override
  State<LeaderboardPage> createState()=>_LeaderboardPageState();
}
class _LeaderboardPageState extends State<LeaderboardPage> {
  String? selected;
  bool consent=false;
  @override
  Widget build(BuildContext context){
    selected??=widget.state.exams.isNotEmpty?widget.state.exams.first.id:null;
    return PageWrap(title:'Bảng xếp hạng',child:ListView(padding:const EdgeInsets.all(18),children:[
      const Surface(child:Text('Bảng xếp hạng chỉ hiển thị học viên tự chọn công khai biệt danh. Điểm được lấy từ kết quả đã nộp.')),
      const SizedBox(height:12),if(widget.state.exams.isNotEmpty)DropdownButtonFormField<String>(initialValue:selected,decoration:const InputDecoration(labelText:'Chọn đề thi'),isExpanded:true,
        items:widget.state.exams.map((e)=>DropdownMenuItem(value:e.id,child:Text(e.title,maxLines:1,overflow:TextOverflow.ellipsis))).toList(),
        onChanged:(v)=>setState(()=>selected=v)),
      CheckboxListTile(value:consent,onChanged:(v)async{
        setState(()=>consent=v??false);
        try{await widget.state.repo.setLeaderboardOptIn(consent);}catch(e){if(mounted) showError(context,e);}
      },title:const Text('Cho phép công khai biệt danh của tôi'),subtitle:const Text('Có thể tắt bất kỳ lúc nào.')),
      const SectionHeading('Kết quả'),
      if(widget.state.repo.isDemo||widget.state.repo.user==null)const Surface(child:Text('Đăng nhập và kết nối máy chủ để xem bảng xếp hạng.'))
      else FutureBuilder(future:widget.state.repo.leaderboard(selected!),builder:(ctx,s){
        if(!s.hasData)return const Center(child:CircularProgressIndicator());
        if(s.data!.isEmpty)return const Surface(child:Text('Chưa có kết quả công khai.'));
        return Column(children:s.data!.asMap().entries.map((e)=>Padding(padding:const EdgeInsets.only(bottom:8),child:Surface(child:Row(children:[
          Text('#${e.key+1}',style:const TextStyle(color:Palette.blue,fontSize:20,fontWeight:FontWeight.w800)),
          const SizedBox(width:12),Expanded(child:Text(asText(e.value['display_name']))),Text(asDouble(e.value['score']).toStringAsFixed(2),style:const TextStyle(fontWeight:FontWeight.w800)),
        ])))).toList());
      }),
    ]));
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key,required this.state});
  final EduState state;
  @override
  Widget build(BuildContext context)=>PageWrap(title:'Tùy chọn học tập',child:AnimatedBuilder(animation:state,builder:(ctx,_)=>ListView(padding:const EdgeInsets.all(18),children:[
    const SectionHeading('Chữ và khả năng đọc'),
    Surface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Cỡ chữ trong ứng dụng',style:TextStyle(fontWeight:FontWeight.w800)),
      const SizedBox(height:6),Text('${(state.textScale*100).round()}% · Chạm hoặc kéo để thay đổi',style:const TextStyle(color:Palette.muted)),
      Slider(min:.85,max:1.35,divisions:10,value:state.textScale,
        onChanged:(v)=>state.updatePreferences(scale:v)),
      const RichMathText(r'Bản xem trước: $\frac{a}{b}$ và các nội dung dài sẽ tự xuống dòng.'),
    ])),
    const SizedBox(height:12),Surface(child:Column(children:[
      SwitchListTile(title:const Text('Tương phản cao'),subtitle:const Text('Làm nền sáng hơn, tăng độ rõ của màu chủ đạo.'),
        value:state.strongContrast,onChanged:(v)=>state.updatePreferences(contrast:v)),
      const Divider(height:1),SwitchListTile(title:const Text('Giảm chuyển động'),subtitle:const Text('Giảm hiệu ứng chuyển trang và chuyển động theo hệ thống.'),
        value:state.reduceMotion,onChanged:(v)=>state.updatePreferences(lessMotion:v)),
    ])),
    const SizedBox(height:12),const Surface(child:Text('Các thiết lập được lưu trên thiết bị. Quy định G2 không thay đổi theo thiết lập hiển thị.')),
  ])));
}
