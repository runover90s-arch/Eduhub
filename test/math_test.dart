import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduhub/widgets/rich_math.dart';

void main() {
  test('splits inline and display latex without losing prose', () {
    final pieces=splitMath(r'Cho $f(x)=x^2$ và $$\int_0^1 x\,dx$$.');
    expect(pieces.length,5);
    expect(pieces[1].value,'f(x)=x^2');
    expect(pieces[3].display,isTrue);
    expect(pieces[3].value,contains(r'\int'));
  });
  test('plain Vietnamese string stays a text segment', () {
    final pieces=splitMath('Một hàm số liên tục trên tập xác định.');
    expect(pieces.length,1);
    expect(pieces.single.isMath,isFalse);
  });
  testWidgets('math expression uses a native Flutter math widget',(tester) async {
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:RichMathText(r'Giải $x^2-4=0$.'))));
    expect(find.byType(Math),findsOneWidget);
  });
}
