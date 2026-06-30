import 'package:flutter/material.dart';

/// Industrial monitoring palette for TEC sensor dashboard.
abstract final class AppTheme {
  static const Color _deepSlate = Color(0xFF0D1117);
  static const Color _panel = Color(0xFF161B22);
  static const Color _electricCyan = Color(0xFF00D4AA);
  static const Color _amberSignal = Color(0xFFF5A623);
  static const Color _mutedText = Color(0xFF8B949E);
  static const Color _primaryText = Color(0xFFE6EDF3);

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      surface: _panel,
      primary: _electricCyan,
      secondary: _amberSignal,
      onSurface: _primaryText,
      onPrimary: _deepSlate,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _deepSlate,
      colorScheme: colorScheme,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: _panel,
        foregroundColor: _primaryText,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: _panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: _primaryText,
        ),
        bodyMedium: TextStyle(color: _mutedText),
        labelLarge: TextStyle(
          fontWeight: FontWeight.w500,
          color: _electricCyan,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
