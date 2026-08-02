import 'package:flutter/material.dart';

/// 配色规范见 docs/06-UI-UX设计规范.md 第 2 节。
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF00D9A6); // 电光青
  static const Color secondary = Color(0xFFFF6B35); // 能量橙
  static const Color heartRed = Color(0xFFFF4757); // 心率红

  static const Color bgDark = Color(0xFF0E1116);
  static const Color surfaceDark = Color(0xFF1C2128);
  static const Color surfaceDarkHigh = Color(0xFF2D333B);

  /// 心率区间色带 Z1–Z5
  static const List<Color> zoneColors = <Color>[
    Color(0xFF4ECDC4), // Z1 蓝绿
    Color(0xFF95E06C), // Z2 绿
    Color(0xFFFFD93D), // Z3 黄
    Color(0xFFFF9F45), // Z4 橙
    Color(0xFFFF4757), // Z5 红
  ];

  static Color zoneColor(int zone) {
    if (zone < 1 || zone > 5) return surfaceDarkHigh;
    return zoneColors[zone - 1];
  }
}

/// 课型徽章色：E 绿 / M 蓝 / T 橙 / I 红 / R 紫 / L 青。
Color workoutTypeColor(String type) {
  switch (type.toUpperCase()) {
    case 'E':
    case 'RECOVERY':
      return const Color(0xFF95E06C);
    case 'M':
      return const Color(0xFF4A9DFF);
    case 'T':
      return const Color(0xFFFF9F45);
    case 'I':
      return const Color(0xFFFF4757);
    case 'R':
      return const Color(0xFFB56BFF);
    case 'L':
      return const Color(0xFF4ECDC4);
    case 'RACE':
      return AppColors.secondary;
    case 'XT':
      return const Color(0xFF8D9BB0);
    case 'REST':
      return const Color(0xFF5A6472);
    default:
      return AppColors.surfaceDarkHigh;
  }
}

/// 训练阶段颜色（基础/进展/巅峰/减量）。
Color phaseColor(String phase) {
  switch (phase.toLowerCase()) {
    case 'base':
    case '基础期':
      return const Color(0xFF4A9DFF);
    case 'build':
    case '进展期':
      return const Color(0xFF00D9A6);
    case 'peak':
    case '巅峰期':
      return const Color(0xFFFF9F45);
    case 'taper':
    case '减量期':
      return const Color(0xFFB56BFF);
    default:
      return AppColors.surfaceDarkHigh;
  }
}

ThemeData buildDarkTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    error: AppColors.heartRed,
    surface: AppColors.surfaceDark,
    onSurface: const Color(0xFFE6EAF0),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bgDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgDark,
      elevation: 0,
      centerTitle: false,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

ThemeData buildLightTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: const Color(0xFF00805F),
    secondary: AppColors.secondary,
    error: AppColors.heartRed,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
