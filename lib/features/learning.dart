import 'package:flutter/material.dart';
import '../core/design.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../main.dart';
import '../widgets/rich_math.dart';

class LessonPage extends StatefulWidget {
  const LessonPage({super.key,required this.repo,required this.lesson});
  final EduRepository repo;
  final Lesson lesson;
  @override
  State<LessonPage> createState()=>_LessonPageState();
}
class _LessonPageState extends State<LessonPage> {
  final noteCtrl=TextEditingController();
  String? body;
  String? error;
  bool completed=false,loading=true;
  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async {
    try {
      final text=await widget.repo.lessonBody(widget.lesson);
      final note=await widget.repo.note(widget.lesson.id);
      if(mounted) setState((){body=text;noteCtrl.text=note.$1;completed=note.$2;loading=false;});
    } catch(e){if(mounted) setState((){error=e.toString();loading=false;});}
  }
  Future<void> _save() async {
    try {await widget.repo.setNote(widget.lesson.id,noteCtrl.text,completed:completed);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Đã lưu tiến độ và ghi chú.')));
    } catch(e){if(mounted) showError(context,e);}
  }
  @override
  void dispose(){noteCtrl.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>PageWrap(title:'Bài học',child:loading?const Center(child:CircularProgressIndicator()):error!=null?
    Padding(padding:const EdgeInsets.all(24),child:Text(error!)):ListView(padding:const EdgeInsets.all(18),children:[
    Text(widget.lesson.title,style:Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height:7),Text('${widget.lesson.subject} · Lớp ${widget.lesson.grade} · ${widget.lesson.minutes} phút',style:const TextStyle(color:Palette.muted)),
    const SizedBox(height:18),Surface(child:RichMathText(body!,fontSize:16)),
    const SectionHeading('Ghi chú của tôi'),
    TextField(controller:noteCtrl,maxLines:5,decoration:const InputDecoration(hintText:'Ghi lại công thức, ý chính hoặc điều cần ôn...')),
    const SizedBox(height:8),CheckboxListTile(value:completed,title:const Text('Đã học xong bài này'),onChanged:(v)=>setState(()=>completed=v??false),controlAffinity:ListTileControlAffinity.leading),
    ElevatedButton.icon(onPressed:_save,icon:const Icon(Icons.save_outlined),label:const Text('Lưu ghi chú và tiến độ')),
    const SizedBox(height:25),
  ]));
}
