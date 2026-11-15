import 'package:flutter/foundation.dart';
import '../data/models.dart';
import '../data/repository.dart';

class EduState extends ChangeNotifier {
  EduState(this.repo);
  final EduRepository repo;
  List<Exam> exams = [];
  List<Lesson> lessons = [];
  List<StudyPackage> packages = [];
  bool loading = true;
  String? error;
  double textScale=1;
  bool strongContrast=false;
  bool reduceMotion=false;

  Future<void> restorePreferences() async {
    textScale=double.tryParse(await repo.cache.getString('eh_text_scale')??'1')?.clamp(.85,1.35).toDouble()??1;
    strongContrast=await repo.cache.getBool('eh_contrast')??false;
    reduceMotion=await repo.cache.getBool('eh_less_motion')??false;
    notifyListeners();
  }
  Future<void> updatePreferences({double? scale,bool? contrast,bool? lessMotion}) async {
    if(scale!=null){textScale=scale.clamp(.85,1.35).toDouble();await repo.cache.setString('eh_text_scale',textScale.toString());}
    if(contrast!=null){strongContrast=contrast;await repo.cache.setBool('eh_contrast',contrast);}
    if(lessMotion!=null){reduceMotion=lessMotion;await repo.cache.setBool('eh_less_motion',lessMotion);}
    notifyListeners();
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait<dynamic>([repo.exams(), repo.lessons(), repo.packages()]);
      exams = List<Exam>.from(results[0] as List);
      lessons = List<Lesson>.from(results[1] as List);
      packages = List<StudyPackage>.from(results[2] as List);
    } catch (e) { error = e.toString(); }
    finally { loading = false; notifyListeners(); }
  }
}
