import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Colours modelled on the classic blue messenger look.
class AppColors {
  static const primary = Color(0xFF517DA2);
  static const accent = Color(0xFF3390EC);
  static const chatBg = Color(0xFFCFE0C3);
  static const outBubble = Color(0xFFEFFDDE);
  static const inBubble = Colors.white;
  static const outMeta = Color(0xFF5FAE53);
  static const inMeta = Color(0xFFA1AAB3);
  static const subtitle = Color(0xFF8D969E);
  static const divider = Color(0xFFE7E7E7);
  static const unread = Color(0xFF4FAE4E);

  static const avatarPalette = [
    Color(0xFFE17076),
    Color(0xFFFAA774),
    Color(0xFFA695E7),
    Color(0xFF7BC862),
    Color(0xFF6EC9CB),
    Color(0xFF65AADD),
    Color(0xFFEE7AAE),
  ];
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: false,
    colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary, primary: AppColors.primary),
    scaffoldBackgroundColor: Colors.white,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
    ),
    dividerColor: AppColors.divider,
  );
}
