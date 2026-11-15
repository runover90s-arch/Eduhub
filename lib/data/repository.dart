import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'grading.dart';
import 'models.dart';

class EduRepository {
  EduRepository(this.client);
  final SupabaseClient? client;
  final SharedPreferencesAsync cache = SharedPreferencesAsync();
  Map<String, dynamic> _demo = {};
  bool get isDemo => client == null;
  User? get user => client?.auth.currentUser;
  String get displayName {
    final name = user?.userMetadata?['full_name']?.toString().trim();
    return name?.isNotEmpty == true ? name! : (user?.email?.split('@').first ?? 'Học viên');
  }
  bool get isAdmin => user?.appMetadata['role'] == 'admin';
  bool get isTeacher => isAdmin || user?.appMetadata['role'] == 'teacher';

  Future<void> initialize() async {
    if (isDemo) _demo = asMap(jsonDecode(await rootBundle.loadString('assets/data/demo.json')));
  }

  Future<List<Exam>> exams() async {
    if (isDemo) return asList(_demo['exams']).map((e) => Exam.fromJson(asMap(e))).toList();
    final rows = await client!.from('eh_exams').select().eq('status', 'published').order('created_at', ascending:false);
    return (rows as List).map((e) => Exam.fromJson(asMap(e))).toList();
  }

  Future<List<Lesson>> lessons() async {
    if (isDemo) return asList(_demo['lessons']).map((e) => Lesson.fromJson(asMap(e))).toList();
    final rows = await client!.from('eh_lessons').select().eq('status','published').order('created_at',ascending:false);
    return (rows as List).map((e) => Lesson.fromJson(asMap(e))).toList();
  }

  Future<String> lessonBody(Lesson lesson) async {
    if (isDemo) return lesson.body;
    final row = await client!.from('eh_lesson_bodies').select('body').eq('lesson_id',lesson.id).maybeSingle();
    if (row == null) throw StateError('Bài học này yêu cầu quyền truy cập phù hợp.');
    return asText(row['body']);
  }

  Future<List<StudyPackage>> packages() async {
    if (isDemo) return asList(_demo['packages']).map((e) => StudyPackage.fromJson(asMap(e))).toList();
    final rows = await client!.from('eh_packages').select().eq('is_active',true).order('price_vnd');
    return (rows as List).map((e) => StudyPackage.fromJson(asMap(e))).toList();
  }

  Future<List<ExamQuestion>> questions(Exam exam) async {
    if (isDemo) return exam.demoQuestions;
    final rows = await client!.from('eh_questions').select().eq('exam_id',exam.id).order('position');
    if ((rows as List).isEmpty) throw StateError('Đề chưa mở hoặc tài khoản chưa có quyền truy cập.');
    return rows.map((e) => ExamQuestion.fromJson(asMap(e))).toList();
  }

  Future<String> startExam(String examId) async {
    if (isDemo) {
      final cached=await cache.getString('eh_active_session_$examId');
      if (cached!=null) return cached;
      final created='local-${DateTime.now().microsecondsSinceEpoch}';
      await cache.setString('eh_active_session_$examId',created);
      return created;
    }
    final result = await client!.rpc('eh_start_attempt', params:{'p_exam_id':examId});
    return asText(result);
  }

  Future<(DateTime,Map<String,dynamic>)> sessionInfo(String id) async {
    if(isDemo){
      final micros=int.tryParse(id.replaceFirst('local-',''));
      return (micros==null?DateTime.now():DateTime.fromMicrosecondsSinceEpoch(micros),<String,dynamic>{});
    }
    final row=await client!.from('eh_exam_sessions').select('started_at,last_draft')
      .eq('id',id).single();
    return (DateTime.parse(asText(row['started_at'])).toLocal(),asMap(row['last_draft']));
  }

  Future<void> syncDraft(String sessionId,Map<String,dynamic> answers) async {
    if (isDemo || user==null) return;
    await client!.rpc('eh_save_draft',params:{'p_session':sessionId,'p_answers':answers});
  }

  Future<void> logIncident(String sessionId, String kind, String eventKey) async {
    if(isDemo){
      final key='eh_incidents_$sessionId';
      final stored=asList(jsonDecode(await cache.getString(key)??'[]')).map((e)=>asText(e)).toSet();
      stored.add(eventKey);
      await cache.setString(key,jsonEncode(stored.toList()));
      return;
    }
    await client!.rpc('eh_log_incident',params:{'p_session':sessionId,'p_kind':kind,'p_event_key':eventKey});
  }

  Future<ExamResult> submitExam(String examId, String sessionId,
      List<ExamQuestion> questions, Map<String,dynamic> answers, int demoIncidentCount) async {
    if (isDemo) {
      final stored=asList(jsonDecode(await cache.getString('eh_incidents_$sessionId')??'[]'));
      final result = GradeCalculator.calculate(examId,sessionId,questions,answers,
        stored.length>demoIncidentCount?stored.length:demoIncidentCount);
      final history = await localHistory();
      history.insert(0,result);
      await cache.setString('eh_demo_attempts',jsonEncode(history.take(50).map((e) => e.toJson()).toList()));
      return result;
    }
    final result = await client!.rpc('eh_submit_attempt',params:{'p_session':sessionId,'p_answers':answers});
    return ExamResult.fromJson(asMap(result));
  }

  Future<List<ExamResult>> localHistory() async {
    final raw = await cache.getString('eh_demo_attempts');
    if (raw == null) return [];
    try { return asList(jsonDecode(raw)).map((e) => ExamResult.fromJson(asMap(e))).toList(); }
    catch (_) { return []; }
  }

  Future<List<ExamResult>> attemptHistory() async {
    if (isDemo) return localHistory();
    if (user == null) return [];
    final rows = await client!.from('eh_attempts').select().eq('user_id',user!.id).order('created_at',ascending:false).limit(50);
    return (rows as List).map((e) => ExamResult.fromJson(asMap(e))).toList();
  }

  Future<void> saveDraft(String examId,String sessionId, Map<String,dynamic> answers) async {
    await cache.setString('eh_draft_$examId',jsonEncode({'session':sessionId,'answers':answers}));
  }
  Future<Map<String,dynamic>> readDraft(String examId,String sessionId) async {
    try {
      final payload=asMap(jsonDecode(await cache.getString('eh_draft_$examId') ?? '{}'));
      if(payload['session']!=sessionId)return {};
      return asMap(payload['answers']);
    } catch (_) { return {}; }
  }
  Future<void> clearDraft(String examId) async {
    await cache.remove('eh_draft_$examId');
    await cache.remove('eh_active_session_$examId');
  }

  Future<void> setNote(String lessonId, String note, {bool completed = false}) async {
    if (!isDemo && user != null) {
      await client!.from('eh_lesson_progress').upsert({
        'user_id':user!.id,'lesson_id':lessonId,'note':note,'completed':completed,
      },onConflict:'user_id,lesson_id');
    } else {
      await cache.setString('eh_note_$lessonId', note);
      await cache.setBool('eh_done_$lessonId',completed);
    }
  }
  Future<(String,bool)> note(String lessonId) async {
    if (!isDemo && user != null) {
      final row = await client!.from('eh_lesson_progress').select('note,completed').eq('user_id',user!.id).eq('lesson_id',lessonId).maybeSingle();
      return (asText(row?['note']),row?['completed']==true);
    }
    return (await cache.getString('eh_note_$lessonId') ?? '', await cache.getBool('eh_done_$lessonId') ?? false);
  }

  Future<void> signIn(String email, String password) async {
    if (isDemo) throw StateError('Đang chạy demo. Hãy cấu hình Supabase để đăng nhập thật.');
    await client!.auth.signInWithPassword(email:email,password:password);
  }
  Future<void> signUp(String name, String email, String password) async {
    if (isDemo) throw StateError('Hãy cấu hình Supabase để tạo tài khoản.');
    await client!.auth.signUp(email:email,password:password,data:{'full_name':name});
  }
  Future<void> resetPassword(String email) async {
    if (isDemo) throw StateError('Chưa cấu hình máy chủ tài khoản.');
    await client!.auth.resetPasswordForEmail(email);
  }
  Future<void> signOut() async { if (!isDemo) await client!.auth.signOut(); }

  Future<void> requestPackage(String packageId) async {
    if (isDemo || user == null) throw StateError('Đăng nhập để gửi yêu cầu đăng ký gói.');
    await client!.from('eh_orders').insert({'package_id':packageId,'user_id':user!.id,'status':'pending'});
  }
  Future<List<Map<String,dynamic>>> myOrders() async {
    if (isDemo || user == null) return [];
    final rows=await client!.from('eh_orders').select('id,package_id,status,created_at').eq('user_id',user!.id).order('created_at',ascending:false);
    return (rows as List).map((e)=>asMap(e)).toList();
  }
  Future<List<Map<String,dynamic>>> leaderboard(String examId) async {
    if (isDemo || user == null) return [];
    final rows=await client!.rpc('eh_leaderboard',params:{'p_exam_id':examId});
    return asList(rows).map((e)=>asMap(e)).toList();
  }
  Future<void> setLeaderboardOptIn(bool value) async {
    if (isDemo || user == null) return;
    await client!.from('eh_profiles').update({'leaderboard_opt_in':value}).eq('id',user!.id);
  }

  Future<List<Map<String,dynamic>>> notifications() async {
    if (isDemo || user == null) return [];
    final rows=await client!.from('eh_notifications').select().eq('user_id',user!.id).order('created_at',ascending:false).limit(50);
    return (rows as List).map((e)=>asMap(e)).toList();
  }
  Future<void> markNotificationRead(String id) async {
    if (isDemo || user == null) return;
    await client!.from('eh_notifications').update({'is_read':true}).eq('id',id).eq('user_id',user!.id);
  }

  Future<List<Map<String,dynamic>>> myClasses() async {
    if (isDemo || user == null) return [];
    final rows = await client!.from('eh_classes').select('id,name,join_code,teacher_id,created_at').order('created_at',ascending:false);
    return (rows as List).map((e)=>asMap(e)).toList();
  }
  Future<List<Map<String,dynamic>>> classAssignments(String classId) async {
    if(isDemo || user==null)return [];
    final rows=await client!.from('eh_assignments').select('id,exam_id,due_at')
      .eq('class_id',classId).order('created_at',ascending:false);
    return (rows as List).map((e)=>asMap(e)).toList();
  }
  Future<List<Map<String,dynamic>>> classOverview(String classId) async {
    if(!isTeacher)return [];
    final rows=await client!.rpc('eh_class_overview',params:{'p_class':classId});
    return asList(rows).map((e)=>asMap(e)).toList();
  }

  Future<void> joinClass(String code) async {
    if (isDemo || user == null) throw StateError('Đăng nhập để tham gia lớp.');
    await client!.rpc('eh_join_class',params:{'p_code':code.trim().toUpperCase()});
  }
  Future<void> createClass(String name) async {
    if (!isTeacher) throw StateError('Chỉ giáo viên hoặc quản trị viên được tạo lớp.');
    await client!.from('eh_classes').insert({'name':name,'teacher_id':user!.id});
  }
  Future<void> assignExam(String classId, String examId) async {
    if (!isTeacher) throw StateError('Không có quyền giao đề.');
    await client!.from('eh_assignments').insert({'class_id':classId,'exam_id':examId});
  }

  // ADMIN: every operation also has SQL RLS checking signed app_metadata roles.
  Future<List<Map<String,dynamic>>> adminExams() async {
    if (!isAdmin) return [];
    final rows=await client!.from('eh_exams').select().order('created_at',ascending:false);
    return (rows as List).map((e)=>asMap(e)).toList();
  }
  Future<String> createExam(Map<String,dynamic> data) async {
    if (!isAdmin) throw StateError('Không có quyền quản trị.');
    final row=await client!.from('eh_exams').insert({...data,'status':'draft','created_by':user!.id}).select('id').single();
    return asText(row['id']);
  }
  Future<void> addQuestion(String examId, Map<String,dynamic> question, dynamic key, String explanation) async {
    if(!isAdmin)throw StateError('Không có quyền quản trị.');
    await client!.rpc('eh_admin_add_question',params:{
      'p_exam_id':examId,
      'p_position':question['position'],'p_kind':question['kind'],
      'p_prompt':question['prompt'],'p_options':question['options'] ?? [],
      'p_statements':question['statements'] ?? [],'p_pairs':question['pairs'] ?? [],
      'p_points':question['points'] ?? 1,'p_answer':key ?? {'manual':true},
      'p_explanation':explanation,'p_image_url':question['image_url'] ?? '',
    });
  }
  Future<void> publishExam(String id) async {
    if (!isAdmin) throw StateError('Không có quyền quản trị.');
    await client!.from('eh_exams').update({'status':'published'}).eq('id',id);
  }
  Future<void> archiveExam(String id) async {
    if (!isAdmin) throw StateError('Không có quyền quản trị.');
    await client!.from('eh_exams').update({'status':'archived'}).eq('id',id);
  }
  Future<String> createLesson(Map<String,dynamic> info, String body) async {
    if (!isAdmin) throw StateError('Không có quyền quản trị.');
    final row=await client!.from('eh_lessons').insert({...info,'status':'draft','created_by':user!.id}).select('id').single();
    final id=asText(row['id']);
    await client!.from('eh_lesson_bodies').insert({'lesson_id':id,'body':body});
    return id;
  }
  Future<void> publishLesson(String id) async {
    if (!isAdmin) throw StateError('Không có quyền quản trị.');
    await client!.from('eh_lessons').update({'status':'published'}).eq('id',id);
  }
  Future<void> createPackage(Map<String,dynamic> data, List<String> examIds, List<String> lessonIds) async {
    if(!isAdmin)throw StateError('Không có quyền quản trị.');
    final item=await client!.from('eh_packages').insert(data).select('id').single();
    final packageId=asText(item['id']);
    if(examIds.isNotEmpty){
      await client!.from('eh_package_exams').insert(examIds.map((id)=>{'package_id':packageId,'exam_id':id}).toList());
    }
    if(lessonIds.isNotEmpty){
      await client!.from('eh_package_lessons').insert(lessonIds.map((id)=>{'package_id':packageId,'lesson_id':id}).toList());
    }
  }

  Future<List<Map<String,dynamic>>> adminOrders() async {
    if (!isAdmin) return [];
    final rows=await client!.from('eh_orders').select().order('created_at',ascending:false);
    return (rows as List).map((e)=>asMap(e)).toList();
  }
  Future<void> approveOrder(String id) async {
    if (!isAdmin) throw StateError('Không có quyền quản trị.');
    await client!.rpc('eh_approve_order',params:{'p_order_id':id});
  }
  Future<void> waiveIncident(String id, String reason) async {
    if (!isAdmin) throw StateError('Không có quyền quản trị.');
    await client!.rpc('eh_waive_incident',params:{'p_incident_id':id,'p_reason':reason});
  }
  Future<List<Map<String,dynamic>>> adminIncidents() async {
    if (!isAdmin) return [];
    final rows=await client!.from('eh_incidents').select().order('created_at',ascending:false).limit(100);
    return (rows as List).map((e)=>asMap(e)).toList();
  }
  Future<void> gradeEssay(String sessionId,String questionId,double awarded) async {
    if (!isAdmin) throw StateError('Không có quyền quản trị.');
    await client!.rpc('eh_grade_essay',params:{'p_session':sessionId,'p_question_id':questionId,'p_awarded':awarded});
  }
  Future<List<Map<String,dynamic>>> pendingEssays() async {
    if (!isAdmin) return [];
    final rows=await client!.from('eh_attempts').select().gt('pending_count',0).limit(100);
    return (rows as List).map((e)=>asMap(e)).toList();
  }
}
