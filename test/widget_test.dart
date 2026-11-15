import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduhub/core/design.dart';
import 'package:eduhub/features/home.dart';

void main() {
  testWidgets('EduHub banner has a clear learning purpose',(tester) async {
    await tester.pumpWidget(MaterialApp(theme:eduhubTheme(),home:const Scaffold(body:EduBanner())));
    expect(find.textContaining('HỌC CHẮC'),findsOneWidget);
    expect(find.byIcon(Icons.school_outlined),findsOneWidget);
  });
}
