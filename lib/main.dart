import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_state.dart';
import 'core/design.dart';
import 'data/repository.dart';
import 'features/account.dart';
import 'features/catalog.dart';
import 'features/exam.dart' show openExam;
import 'features/home.dart';
import 'features/packages.dart';

const backendUrl = String.fromEnvironment('SUPABASE_URL');
const backendKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseClient? client;
  if (backendUrl.isNotEmpty && backendKey.isNotEmpty) {
    await Supabase.initialize(url: backendUrl, publishableKey: backendKey);
    client = Supabase.instance.client;
  }
  final repo = EduRepository(client);
  await repo.initialize();
  runApp(EduHubApp(repo: repo));
}

class EduHubApp extends StatefulWidget {
  const EduHubApp({super.key, required this.repo});
  final EduRepository repo;
  @override
  State<EduHubApp> createState() => _EduHubAppState();
}
class _EduHubAppState extends State<EduHubApp> {
  late final EduState state = EduState(widget.repo);
  StreamSubscription<AuthState>? _subscription;
  @override
  void initState() {
    super.initState();
    unawaited(state.restorePreferences());
    unawaited(state.refresh());
    _subscription = widget.repo.client?.auth.onAuthStateChange.listen((_) {
      if (mounted) unawaited(state.refresh());
    });
  }
  @override
  void dispose() { _subscription?.cancel(); state.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation:state,builder:(context,_)=>MaterialApp(
    title: 'EduHub', debugShowCheckedModeBanner:false, theme:eduhubTheme(highContrast:state.strongContrast,reduceMotion:state.reduceMotion),
    builder:(ctx,child){
      final media=MediaQuery.of(ctx);
      return MediaQuery(data:media.copyWith(textScaler:TextScaler.linear(state.textScale),
        disableAnimations:state.reduceMotion),child:child??const SizedBox.shrink());
    },
    home: AppShell(state:state),
  ));
}

class AppShell extends StatefulWidget {
  const AppShell({super.key,required this.state});
  final EduState state;
  @override
  State<AppShell> createState() => _AppShellState();
}
class _AppShellState extends State<AppShell> {
  int index=0;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation:widget.state,builder:(context,_) {
      final state=widget.state;
      if (state.loading && state.exams.isEmpty) {
        return const Scaffold(body:Center(child:CircularProgressIndicator()));
      }
      if (state.error != null && state.exams.isEmpty) {
        return Scaffold(body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(
          mainAxisSize:MainAxisSize.min, children:[
          const Icon(Icons.cloud_off_outlined,size:50,color:Palette.muted),const SizedBox(height:16),
          Text('Không thể tải dữ liệu',style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:8),Text(state.error!,textAlign:TextAlign.center),
          const SizedBox(height:16),ElevatedButton(onPressed:state.refresh,child:const Text('Thử lại')),
        ]))));
      }
      return Scaffold(
        body:SafeArea(top:false,child:IndexedStack(index:index,children:[
          HomeTab(state:state,onExamTap:(exam)=>openExam(context, state, exam), onGoTab:(i)=>setState(()=>index=i)),
          CatalogTab(state:state,onExamTap:(exam)=>openExam(context, state, exam)),
          ActivityTab(state:state,onGoCatalog:()=>setState(()=>index=1)),
          PackagesTab(state:state),
          AccountTab(state:state),
        ])),
        bottomNavigationBar:NavigationBar(
          backgroundColor:Colors.white, indicatorColor:const Color(0xFFE8F0FF),
          selectedIndex:index, onDestinationSelected:(next)=>setState(()=>index=next),
          labelBehavior:NavigationDestinationLabelBehavior.alwaysShow,
          destinations:const [
            NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Trang chủ'),
            NavigationDestination(icon:Icon(Icons.menu_book_outlined),selectedIcon:Icon(Icons.menu_book),label:'Đánh giá'),
            NavigationDestination(icon:Icon(Icons.assignment_outlined),selectedIcon:Icon(Icons.assignment),label:'Bài làm'),
            NavigationDestination(icon:Icon(Icons.shopping_bag_outlined),selectedIcon:Icon(Icons.shopping_bag),label:'Gói mua'),
            NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Cá nhân'),
          ],
        ),
      );
    });
  }
}

Future<T?> pushScreen<T>(BuildContext context,Widget screen) => Navigator.of(context).push<T>(MaterialPageRoute(builder:(_)=>screen));
void showError(BuildContext context,Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(error.toString().replaceFirst('Exception: ',''))));
}

class PageWrap extends StatelessWidget {
  const PageWrap({super.key,required this.title,required this.child,this.actions=const []});
  final String title;
  final Widget child;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(title),actions:actions),body:SafeArea(child:child));
}
