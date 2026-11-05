import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardThemeProfile {
  final String dashboardType; // Dashboard category or canonical account role.
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final String? fontFamily;

  DashboardThemeProfile({
    required this.dashboardType,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.backgroundColor,
    this.fontFamily,
  });

  Map<String, int> toJson() {
    return {
      'primaryColor': primaryColor.toARGB32(),
      'secondaryColor': secondaryColor.toARGB32(),
      'accentColor': accentColor.toARGB32(),
      'backgroundColor': backgroundColor.toARGB32(),
    };
  }

  DashboardThemeProfile copyWith({
    Color? primaryColor,
    Color? secondaryColor,
    Color? accentColor,
    Color? backgroundColor,
    String? fontFamily,
    bool resetFontFamily = false,
  }) {
    return DashboardThemeProfile(
      dashboardType: dashboardType,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      accentColor: accentColor ?? this.accentColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontFamily: resetFontFamily ? null : (fontFamily ?? this.fontFamily),
    );
  }

  factory DashboardThemeProfile.fromJson(
    String dashboardType,
    Map<String, dynamic> json,
  ) => DashboardThemeProfile(
    dashboardType: dashboardType,
    primaryColor: Color((json['primaryColor'] as int?) ?? 0xFFFF69B4),
    secondaryColor: Color((json['secondaryColor'] as int?) ?? 0xFFFFB6C1),
    accentColor: Color((json['accentColor'] as int?) ?? 0xFFF06292),
    backgroundColor: Color((json['backgroundColor'] as int?) ?? 0xFFFFF0F5),
    fontFamily: (json['fontFamily'] as String?)?.trim().isEmpty ?? true
        ? null
        : json['fontFamily'] as String?,
  );

  static DashboardThemeProfile defaultTheme(String dashboardType) {
    switch (dashboardType) {
      case 'parent':
      case 'delegated_parent':
      case 'orang_tua':
      case 'delegasi':
        return DashboardThemeProfile(
          dashboardType: dashboardType,
          primaryColor: const Color(0xFFFF80AB),
          secondaryColor: const Color(0xFF2C1828),
          accentColor: const Color(0xFFF06292),
          backgroundColor: const Color(0xFF090909),
          fontFamily: null,
        );
      case 'baby':
        return DashboardThemeProfile(
          dashboardType: 'baby',
          primaryColor: const Color(0xFFFF69B4),
          secondaryColor: const Color(0xFFFFB6C1),
          accentColor: const Color(0xFFF06292),
          backgroundColor: const Color(0xFFFFF0F5),
          fontFamily: null,
        );
      case 'toddler':
        return DashboardThemeProfile(
          dashboardType: 'toddler',
          primaryColor: const Color(0xFF9C27B0),
          secondaryColor: const Color(0xFFCE93D8),
          accentColor: const Color(0xFF7B1FA2),
          backgroundColor: const Color(0xFFF3E5F5),
          fontFamily: null,
        );
      case 'balita':
        return DashboardThemeProfile(
          dashboardType: 'balita',
          primaryColor: const Color(0xFF26A69A),
          secondaryColor: const Color(0xFF80CBC4),
          accentColor: const Color(0xFF00897B),
          backgroundColor: const Color(0xFFE0F2F1),
          fontFamily: null,
        );
      case 'anak':
        return DashboardThemeProfile(
          dashboardType: 'anak',
          primaryColor: const Color(0xFF2196F3),
          secondaryColor: const Color(0xFF81D4FA),
          accentColor: const Color(0xFF1976D2),
          backgroundColor: const Color(0xFFE3F2FD),
          fontFamily: null,
        );
      case 'remaja':
        return DashboardThemeProfile(
          dashboardType: 'remaja',
          primaryColor: const Color(0xFF4CAF50),
          secondaryColor: const Color(0xFFA5D6A7),
          accentColor: const Color(0xFF388E3C),
          backgroundColor: const Color(0xFFE8F5E9),
          fontFamily: null,
        );
      default:
        return DashboardThemeProfile(
          dashboardType: dashboardType,
          primaryColor: const Color(0xFFF06292),
          secondaryColor: const Color(0xFF9C27B0),
          accentColor: const Color(0xFFE91E63),
          backgroundColor: const Color(0xFFFCE4EC),
          fontFamily: null,
        );
    }
  }
}

class DashboardFontPreset {
  final String label;
  final String? fontFamily;

  const DashboardFontPreset({required this.label, required this.fontFamily});
}

class DashboardThemeService {
  static const _prefix = 'dashboard_theme_';
  static const fontPresets = <DashboardFontPreset>[
    DashboardFontPreset(label: 'Default', fontFamily: null),
    DashboardFontPreset(label: 'Sans', fontFamily: 'sans-serif'),
    DashboardFontPreset(label: 'Serif', fontFamily: 'serif'),
    DashboardFontPreset(label: 'Monospace', fontFamily: 'monospace'),
  ];

  static Future<DashboardThemeProfile> getTheme(String dashboardType) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$dashboardType';
    final json = prefs.getString(key);

    if (json == null) {
      return DashboardThemeProfile.defaultTheme(dashboardType);
    }

    try {
      final parsed = json.split('|');
      return DashboardThemeProfile.fromJson(dashboardType, {
        'primaryColor': int.parse(parsed[0]),
        'secondaryColor': int.parse(parsed[1]),
        'accentColor': int.parse(parsed[2]),
        'backgroundColor': int.parse(parsed[3]),
        'fontFamily': parsed.length > 4 ? parsed[4] : null,
      });
    } catch (_) {
      return DashboardThemeProfile.defaultTheme(dashboardType);
    }
  }

  static Future<void> saveTheme(DashboardThemeProfile theme) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${theme.dashboardType}';
    final value =
        '${theme.primaryColor.toARGB32()}|${theme.secondaryColor.toARGB32()}|${theme.accentColor.toARGB32()}|${theme.backgroundColor.toARGB32()}|${theme.fontFamily ?? ''}';
    await prefs.setString(key, value);
  }

  static Future<void> resetTheme(String dashboardType) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$dashboardType';
    await prefs.remove(key);
  }
}
