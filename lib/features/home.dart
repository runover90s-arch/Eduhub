import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/design.dart';
import '../data/models.dart';
import '../main.dart';
import 'learning.dart';
import 'account.dart';

const subjects = [
  ('Toán học',Icons.functions, Color(0xFF1866F2)),
  ('Tiếng Anh',Icons.translate, Color(0xFF8B53D9)),
  ('Vật lí',Icons.science_outlined, Color(0xFF00A4A4)),
  ('Hóa học',Icons.biotech_outlined, Color(0xFFDE6D2B)),
  ('Sinh học',Icons.eco_outlined, Color(0xFF14A66C)),
  ('Lịch sử',Icons.public_outlined, Color(0xFF9B6545)),
];

class HomeTab extends StatelessWidget {
  const HomeTab({super.key,required this.state,required this.onExamTap,required this.onGoTab});
  final EduState state;
  final ValueChanged<Exam> onExamTap;
  final ValueChanged<int> onGoTab;
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour<11?'Chào buổi sáng':hour<18?'Chào buổi chiều':'Chào buổi tối';
    return CustomScrollView(slivers:[
      SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.fromLTRB(18,54,18,8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Container(width:42,height:46,decoration:BoxDecoration(color:Palette.blue,borderRadius:BorderRadius.circular(13)),child:const Center(child:Text('E',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:Colors.white)))),
          const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('$greeting, ${state.repo.displayName}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
            const Text('Hôm nay bạn muốn học gì?',style:TextStyle(color:Palette.muted,fontSize:13)),
          ])),
          IconButton(onPressed:()=>pushScreen(context,NotificationsPage(repo:state.repo)),icon:const Icon(Icons.notifications_none_outlined)),
        ]),
        const SizedBox(height:18),
        Surface(onTap:()=>onGoTab(1),padding:const EdgeInsets.symmetric(vertical:14,horizontal:16),child:const Row(children:[
          Icon(Icons.search,color:Palette.muted),SizedBox(width:12),Expanded(child:Text('Tìm đề thi, môn học, chủ đề...',style:TextStyle(color:Palette.muted))),
          Icon(Icons.tune,color:Palette.blue),
        ])),
        const SizedBox(height:16),
        SizedBox(height:36,child:ListView(scrollDirection:Axis.horizontal,children:subjects.take(5).map((s)=>Padding(
          padding:const EdgeInsets.only(right:8),child:ActionChip(
          avatar:Icon(s.$2,color:s.$3,size:17),label:Text(s.$1),onPressed:()=>onGoTab(1),
          backgroundColor:Colors.white,side:const BorderSide(color:Palette.border)),
        )).toList())),
        const SizedBox(height:20),const EduBanner(),
        const SectionHeading('Khám phá theo môn học'),
        GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
          crossAxisCount:3,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:1.17,
          children:subjects.map((s)=>Surface(onTap:()=>onGoTab(1),padding:const EdgeInsets.all(8),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
            Container(width:42,height:42,decoration:BoxDecoration(color:s.$3.withValues(alpha:.10),shape:BoxShape.circle),child:Icon(s.$2,color:s.$3,size:23)),
            const SizedBox(height:8),Text(s.$1,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800,color:Palette.deepBlue),maxLines:1),
          ]))).toList(),
        ),
        SectionHeading('Bài đánh giá nổi bật',trailing:'Xem tất cả',onTap:()=>onGoTab(1)),
        ...state.exams.take(3).map((exam)=>Padding(padding:const EdgeInsets.only(bottom:10),child:ExamListCard(exam:exam,onTap:()=>onExamTap(exam)))),
        const SectionHeading('Bài học mới'),
        ...state.lessons.take(3).map((lesson)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Surface(onTap:()=>pushScreen(context,LessonPage(repo:state.repo,lesson:lesson)),child:Row(children:[
          const Icon(Icons.auto_stories_outlined,color:Palette.blue,size:28),const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(lesson.title,style:const TextStyle(fontWeight:FontWeight.w700)),Text('${lesson.subject} · Lớp ${lesson.grade} · ${lesson.minutes} phút',style:const TextStyle(color:Palette.muted,fontSize:12))])),
          if (lesson.access=='pro') const StateTag('PRO'),const Icon(Icons.chevron_right,color:Palette.muted),
        ])))),
        const SizedBox(height:26),
      ]))),
    ]);
  }
}

class EduBanner extends StatelessWidget {
  const EduBanner({super.key});
  @override
  Widget build(BuildContext context)=>Container(height:174,decoration:BoxDecoration(
    borderRadius:BorderRadius.circular(18),
    gradient:const LinearGradient(colors:[Color(0xFF0C4AD4),Color(0xFF397EF7)],begin:Alignment.topLeft,end:Alignment.bottomRight),
  ),child:Stack(children:[
    Positioned(right:-42,top:-64,child:Container(width:240,height:240,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:Colors.white.withValues(alpha:.18),width:25)))),
    Positioned(right:14,bottom:10,child:Icon(Icons.school_outlined,size:112,color:Colors.white.withValues(alpha:.28))),
    Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('HỌC CHẮC KIẾN THỨC',style:TextStyle(fontSize:11,letterSpacing:1.5,color:Colors.white70,fontWeight:FontWeight.w800)),
      const SizedBox(height:9),const Text('Một nơi cho mỗi\nmục tiêu học tập.',style:TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900,height:1.2)),
      const Spacer(),Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:const Text('Ôn tập · Làm đề · Theo dõi tiến bộ',style:TextStyle(fontWeight:FontWeight.w700,fontSize:11,color:Palette.deepBlue))),
    ])),
  ]));
}

class ExamListCard extends StatelessWidget {
  const ExamListCard({super.key,required this.exam,required this.onTap});
  final Exam exam;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final palette=exam.subject=='Toán học'?Palette.blue:exam.subject=='Vật lí'?const Color(0xFF028F98):const Color(0xFFD67832);
    return Surface(onTap:onTap,child:Row(children:[
      Container(width:64,height:75,decoration:BoxDecoration(color:palette.withValues(alpha:.10),borderRadius:BorderRadius.circular(13)),child:Icon(exam.subject=='Toán học'?Icons.functions:Icons.science_outlined,color:palette,size:36)),
      const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(exam.title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:14)),
        const SizedBox(height:6),Text('${exam.subject} · Lớp ${exam.grade}',style:const TextStyle(color:Palette.muted,fontSize:12)),
        const SizedBox(height:5),Text('${exam.questionCount} câu · ${exam.minutes} phút',style:const TextStyle(color:Palette.muted,fontSize:12)),
      ])),const SizedBox(width:4),if (exam.access=='pro') const StateTag('PRO',color:Palette.purple) else const Icon(Icons.chevron_right,color:Palette.muted),
    ]));
  }
}
