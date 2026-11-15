import 'package:flutter/material.dart';

class Palette {
  static const blue = Color(0xFF125CF5);
  static const deepBlue = Color(0xFF092965);
  static const ink = Color(0xFF202C41);
  static const muted = Color(0xFF687388);
  static const canvas = Color(0xFFF2F5FC);
  static const border = Color(0xFFE3E9F4);
  static const green = Color(0xFF1EAF62);
  static const red = Color(0xFFE04848);
  static const amber = Color(0xFFFFAA23);
  static const purple = Color(0xFF744FE6);
}

ThemeData eduhubTheme({bool highContrast=false,bool reduceMotion=false}) {
  const radius = 16.0;
  return ThemeData(
    visualDensity: highContrast?VisualDensity.standard:VisualDensity.compact,
    useMaterial3: true,
    pageTransitionsTheme: reduceMotion?const PageTransitionsTheme(builders:{
      TargetPlatform.android: NoPageTransitionsBuilder(),
      TargetPlatform.iOS: NoPageTransitionsBuilder(),
      TargetPlatform.fuchsia: NoPageTransitionsBuilder(),
      TargetPlatform.linux: NoPageTransitionsBuilder(),
      TargetPlatform.macOS: NoPageTransitionsBuilder(),
      TargetPlatform.windows: NoPageTransitionsBuilder(),
    }):null,
    scaffoldBackgroundColor: highContrast?Colors.white:Palette.canvas,
    colorScheme: ColorScheme.fromSeed(seedColor: Palette.blue, primary: highContrast?const Color(0xFF003AC8):Palette.blue, surface: Colors.white),
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: Palette.ink, fontSize: 24),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, color: Palette.ink, fontSize: 21),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: Palette.ink, fontSize: 16),
      bodyMedium: TextStyle(color: Palette.ink, fontSize: 14, height: 1.45),
      bodyLarge: TextStyle(color: Palette.ink, fontSize: 16, height: 1.5),
    ),
    cardTheme: CardThemeData(
      elevation: 0, color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.blue, foregroundColor: Colors.white,
      centerTitle: true, elevation: 0,
      titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: Colors.white,
      hintStyle: const TextStyle(color: Palette.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Palette.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Palette.border)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Palette.blue, foregroundColor: Colors.white,
        elevation: 0, minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class Surface extends StatelessWidget {
  const Surface({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color ?? Colors.white,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.trailing, this.onTap});
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 12),
    child: Row(children: [
      Expanded(child: Text(title, style: const TextStyle(color: Palette.deepBlue, fontWeight: FontWeight.w800, fontSize: 19))),
      if (trailing != null) TextButton(onPressed: onTap, child: Text(trailing!)),
    ]),
  );
}

class StateTag extends StatelessWidget {
  const StateTag(this.label, {super.key, this.color = Palette.blue});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
  );
}

String formatVnd(int value) {
  final digits = value.toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return '${out.toString()}đ';
}

// Route animations are skipped when the learner enables reduced motion.
class NoPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route,BuildContext context,
      Animation<double> animation,Animation<double> secondaryAnimation,Widget child)=>child;
}
