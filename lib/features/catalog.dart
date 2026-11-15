import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/design.dart';
import '../data/models.dart';
import '../main.dart';
import 'home.dart';
import 'learning.dart';

String foldVietnamese(String source) {
  var s=source.toLowerCase().replaceAll('đ','d');
  const accented=['àáảãạăằắẳẵặâầấẩẫậ','èéẻẽẹêềếểễệ','ìíỉĩị','òóỏõọôồốổỗộơờớởỡợ','ùúủũụưừứửữự','ỳýỷỹỵ'];
  const plain=['a','e','i','o','u','y'];
  for(var i=0;i<accented.length;i++) {
    for(final rune in accented[i].runes) { s=s.replaceAll(String.fromCharCode(rune),plain[i]); }
  }
  return s;
}

class CatalogTab extends StatefulWidget {
  const CatalogTab({super.key,required this.state,required this.onExamTap});
  final EduState state;
  final ValueChanged<Exam> onExamTap;
  @override
  State<CatalogTab> createState()=>_CatalogTabState();
}
class _CatalogTabState extends State<CatalogTab> {
  String query='',subject='Tất cả',sort='Mới nhất';
  bool onlyFree=false;
  @override
  Widget build(BuildContext context) {
    final exams=widget.state.exams.where((e) =>
      (subject=='Tất cả'||e.subject==subject) &&
      (!onlyFree||e.access=='free') &&
      foldVietnamese('${e.title} ${e.subject} ${e.summary} ${e.grade}').contains(foldVietnamese(query))
    ).toList();
    if(sort=='Thời gian') exams.sort((a,b)=>a.minutes.compareTo(b.minutes));
    if(sort=='Nhiều câu') exams.sort((a,b)=>b.questionCount.compareTo(a.questionCount));
    return Column(children:[
      Container(width:double.infinity,color:Palette.blue,padding:const EdgeInsets.fromLTRB(20,55,20,22),child:const Center(child:Text('Bài đánh giá',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w800)))),
      Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(16,16,16,20),children:[
        TextField(onChanged:(v)=>setState(()=>query=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Tìm bài ôn luyện, môn học, chủ đề...')),
        const SizedBox(height:12),Row(children:[
          Expanded(child:DropdownButtonFormField<String>(initialValue:subject,decoration:const InputDecoration(labelText:'Môn học'),isExpanded:true,
            items:['Tất cả','Toán học','Tiếng Anh','Vật lí','Hóa học','Sinh học','Lịch sử'].map((s)=>DropdownMenuItem(value:s,child:Text(s,style:const TextStyle(fontSize:13)))).toList(),
            onChanged:(v)=>setState(()=>subject=v??'Tất cả'))),
          const SizedBox(width:10),Expanded(child:DropdownButtonFormField<String>(initialValue:sort,decoration:const InputDecoration(labelText:'Sắp xếp'),isExpanded:true,
            items:['Mới nhất','Thời gian','Nhiều câu'].map((s)=>DropdownMenuItem(value:s,child:Text(s,style:const TextStyle(fontSize:13)))).toList(),
            onChanged:(v)=>setState(()=>sort=v??'Mới nhất'))),
        ]),
        SwitchListTile(title:const Text('Chỉ hiện đề miễn phí',style:TextStyle(fontSize:13)),value:onlyFree,onChanged:(v)=>setState(()=>onlyFree=v),dense:true,activeThumbColor:Palette.blue),
        Padding(padding:const EdgeInsets.fromLTRB(4,12,4,10),child:Text('${exams.length} đề phù hợp',style:const TextStyle(color:Palette.deepBlue,fontWeight:FontWeight.w800,fontSize:16))),
        if(exams.isEmpty) const Surface(child:Text('Chưa có đề phù hợp. Thử một bộ lọc khác.')),
        ...exams.map((exam)=>Padding(padding:const EdgeInsets.only(bottom:12),child:ExamListCard(exam:exam,onTap:()=>widget.onExamTap(exam)))),
        const SectionHeading('Thư viện bài học'),
        ...widget.state.lessons.where((l)=>subject=='Tất cả'||l.subject==subject).map((l)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Surface(
          onTap:()=>pushScreen(context,LessonPage(repo:widget.state.repo,lesson:l)),
          child:Row(children:[const Icon(Icons.book_outlined,color:Palette.blue),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(l.title,style:const TextStyle(fontWeight:FontWeight.w700)),Text('${l.subject} · ${l.minutes} phút',style:const TextStyle(color:Palette.muted,fontSize:12)),
          ])),if(l.access=='pro') const StateTag('PRO',color:Palette.purple),const Icon(Icons.chevron_right)]),
        ))),
      ])),
    ]);
  }
}
