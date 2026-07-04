import 'package:flutter/material.dart';

/// Semantic color tokens for TEK Instrument Console theme.
abstract final class TekColors {
  // Dark
  static const darkBackground = Color(0xFF0A0E14);
  static const darkSurface = Color(0xFF121820);
  static const darkSurfaceElevated = Color(0xFF1A2230);
  static const darkBorder = Color(0xFF2A3544);
  static const darkTextPrimary = Color(0xFFE8EDF4);
  static const darkTextMuted = Color(0xFF7D8B9E);

  // Light
  static const lightBackground = Color(0xFFF0F3F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceElevated = Color(0xFFE8ECF2);
  static const lightBorder = Color(0xFFD0D7E2);
  static const lightTextPrimary = Color(0xFF1A2332);
  static const lightTextMuted = Color(0xFF5C6B7E);

  // Brand (shared)
  static const primary = Color(0xFF00C9A7);
  static const primaryDark = Color(0xFF008F7A);
  static const secondary = Color(0xFFE8A838);
  static const error = Color(0xFFF85149);
  static const success = Color(0xFF3FB950);
  static const live = Color(0xFF3FB950);

  /// Entity palette — works on dark and light chart backgrounds.
  static const entityPalette = [
    Color(0xFF00C9A7),
    Color(0xFFE8A838),
    Color(0xFF4DA3FF),
    Color(0xFFE06C75),
    Color(0xFFB794F6),
    Color(0xFF56D4DD),
    Color(0xFFFF7B72),
    Color(0xFFFFA657),
    Color(0xFF7EE787),
    Color(0xFFA371F7),
    Color(0xFF79C0FF),
    Color(0xFFD2A8FF),
  ];

  static const entityPaletteHex = [
    '#00C9A7',
    '#E8A838',
    '#4DA3FF',
    '#E06C75',
    '#B794F6',
    '#56D4DD',
    '#FF7B72',
    '#FFA657',
    '#7EE787',
    '#A371F7',
    '#79C0FF',
    '#D2A8FF',
  ];
}
