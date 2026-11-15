import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../core/design.dart';

// Authoring: inline $...$ and \(...\), display $$...$$ and \[...\].
class MathSegment {
  const MathSegment(this.value, this.isMath, this.display);
  final String value;
  final bool isMath;
  final bool display;
}

List<MathSegment> splitMath(String input) {
  final parts = <MathSegment>[];
  final rx = RegExp(r'\$\$([\s\S]*?)\$\$|\\\[([\s\S]*?)\\\]|\\\(([\s\S]*?)\\\)|(?<!\\)\$([^$\n]+?)\$');
  var start = 0;
  for (final match in rx.allMatches(input)) {
    if (match.start > start) parts.add(MathSegment(input.substring(start, match.start), false, false));
    final content = match.group(1) ?? match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
    parts.add(MathSegment(content.trim(), true, match.group(1) != null || match.group(2) != null));
    start = match.end;
  }
  if (start < input.length) parts.add(MathSegment(input.substring(start), false, false));
  if (parts.isEmpty) parts.add(MathSegment(input, false, false));
  return parts;
}

class RichMathText extends StatelessWidget {
  const RichMathText(this.source, {super.key, this.fontSize = 15, this.color = Palette.ink, this.weight = FontWeight.w400});
  final String source;
  final double fontSize;
  final Color color;
  final FontWeight weight;

  Widget _math(String tex,{required bool display}) {
    final math = Math.tex(tex,mathStyle:display?MathStyle.display:MathStyle.text,
      textStyle:TextStyle(fontSize:fontSize+(display?3:0),color:color),
      onErrorFallback:(_)=>Text('Công thức không hợp lệ: $tex',style:const TextStyle(color:Palette.red,fontSize:13)));
    return display ? SingleChildScrollView(scrollDirection:Axis.horizontal,child:Padding(
      padding:const EdgeInsets.symmetric(vertical:7),child:math)) : Padding(padding:const EdgeInsets.symmetric(horizontal:2),child:math);
  }

  @override
  Widget build(BuildContext context) {
    final spans=splitMath(source);
    final lines=<Widget>[];
    final inline=<Widget>[];
    void flush() {
      if(inline.isNotEmpty){
        lines.add(Wrap(spacing:0,runSpacing:3,crossAxisAlignment:WrapCrossAlignment.center,children:List<Widget>.from(inline)));
        inline.clear();
      }
    }
    for(final segment in spans){
      if(segment.isMath){
        if(segment.display){flush();lines.add(_math(segment.value,display:true));}
        else inline.add(_math(segment.value,display:false));
        continue;
      }
      final paragraphs=segment.value.split('\n');
      for(var i=0;i<paragraphs.length;i++){
        if(i>0){flush();if(paragraphs[i].trim().isEmpty)lines.add(const SizedBox(height:8));}
        // Split text by word to wrap inline formulas within a sentence naturally.
        // Original whitespace is normalized for app readability.
        final words=paragraphs[i].trim().split(RegExp(r'\s+')).where((word)=>word.isNotEmpty);
        for(final word in words){
          inline.add(Text('$word ',style:TextStyle(fontSize:fontSize,color:color,fontWeight:weight,height:1.5)));
        }
      }
    }
    flush();
    if(lines.isEmpty)return const SizedBox.shrink();
    return Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,
      children:lines.map((w)=>Padding(padding:const EdgeInsets.only(bottom:3),child:w)).toList());
  }
}
