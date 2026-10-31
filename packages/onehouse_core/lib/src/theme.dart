import 'package:flutter/material.dart';

/// 한지붕 시리즈 공통 색. 앱마다 다른 대표색은 [buildTheme]의 primary로 넣고,
/// 화면에서는 `Theme.of(context).colorScheme.primary`로 쓴다.
class AppColors {
  static const background = Color(0xFFF5F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF191C1F);
  static const textSecondary = Color(0xFF5F6670);
  static const border = Color(0xFFD5D9DE);
  static const divider = Color(0xFFECEEF1);
  static const danger = Color(0xFFB42318);
  static const income = Color(0xFF1C5FB8);

  // 회색·주황·파랑 라벨: (글자, 배경)
  static const commonFg = Color(0xFF3D434A);
  static const commonBg = Color(0xFFEEF0F3);
  static const expenseFg = Color(0xFF8A4B00);
  static const expenseBg = Color(0xFFFDF0DC);
  static const incomeFg = Color(0xFF1C5FB8);
  static const incomeBg = Color(0xFFE6EEF9);
}

/// 대표색을 아주 옅게 깐 배경 (배지·코드 상자 등)
Color softOf(Color primary) => Color.alphaBlend(primary.withValues(alpha: 0.12), Colors.white);

ThemeData buildTheme(Color primary) {
  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    primary: primary,
    surface: AppColors.surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
    ),
  );
}
