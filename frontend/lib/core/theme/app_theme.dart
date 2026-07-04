import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tek_sensor_monitor/core/theme/color_tokens.dart';

const _themeModeKey = 'tek_theme_mode';
const _reduceMotionKey = 'tek_reduce_motion';

enum AppThemePreference {
  system,
  light,
  dark;

  String get label => switch (this) {
        AppThemePreference.system => 'Системная',
        AppThemePreference.light => 'Светлая',
        AppThemePreference.dark => 'Тёмная',
      };

  IconData get icon => switch (this) {
        AppThemePreference.system => Icons.brightness_auto_outlined,
        AppThemePreference.light => Icons.light_mode_outlined,
        AppThemePreference.dark => Icons.dark_mode_outlined,
      };

  ThemeMode get themeMode => switch (this) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      };

  static AppThemePreference fromStorage(String? value) {
    return AppThemePreference.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppThemePreference.system,
    );
  }

  AppThemePreference next() {
    final index = (AppThemePreference.values.indexOf(this) + 1) %
        AppThemePreference.values.length;
    return AppThemePreference.values[index];
  }
}

class ThemePreferenceNotifier extends StateNotifier<AppThemePreference> {
  ThemePreferenceNotifier() : super(AppThemePreference.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppThemePreference.fromStorage(prefs.getString(_themeModeKey));
  }

  Future<void> setPreference(AppThemePreference preference) async {
    state = preference;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, preference.name);
  }

  Future<void> cycle() => setPreference(state.next());
}

final themePreferenceProvider =
    StateNotifierProvider<ThemePreferenceNotifier, AppThemePreference>(
  (ref) => ThemePreferenceNotifier(),
);

class ReduceMotionNotifier extends StateNotifier<bool> {
  ReduceMotionNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_reduceMotionKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reduceMotionKey, enabled);
  }
}

final reduceMotionProvider =
    StateNotifierProvider<ReduceMotionNotifier, bool>(
  (ref) => ReduceMotionNotifier(),
);

/// Whether UI animations should run (system + user preference).
bool tekAnimationsEnabled(BuildContext context, WidgetRef ref) {
  if (MediaQuery.disableAnimationsOf(context)) return false;
  return !ref.watch(reduceMotionProvider);
}

Duration tekAnimDuration(BuildContext context, WidgetRef ref, Duration normal) {
  return tekAnimationsEnabled(context, ref) ? normal : Duration.zero;
}

abstract final class AppTypography {
  static TextTheme textTheme(Brightness brightness) {
    final primary = brightness == Brightness.dark
        ? TekColors.darkTextPrimary
        : TekColors.lightTextPrimary;
    final muted = brightness == Brightness.dark
        ? TekColors.darkTextMuted
        : TekColors.lightTextMuted;

    return TextTheme(
      displaySmall: GoogleFonts.manrope(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: primary,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: primary,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleSmall: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: GoogleFonts.sourceSans3(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: GoogleFonts.sourceSans3(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      bodySmall: GoogleFonts.sourceSans3(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      labelLarge: GoogleFonts.sourceSans3(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: TekColors.primary,
        letterSpacing: 0.2,
      ),
      labelMedium: GoogleFonts.sourceSans3(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
      labelSmall: GoogleFonts.sourceSans3(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: muted,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ).apply(bodyColor: primary, displayColor: primary);
  }
}

abstract final class AppTheme {
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg =
        isDark ? TekColors.darkBackground : TekColors.lightBackground;
    final surface = isDark ? TekColors.darkSurface : TekColors.lightSurface;
    final elevated =
        isDark ? TekColors.darkSurfaceElevated : TekColors.lightSurfaceElevated;
    final border = isDark ? TekColors.darkBorder : TekColors.lightBorder;
    final onSurface =
        isDark ? TekColors.darkTextPrimary : TekColors.lightTextPrimary;
    final muted =
        isDark ? TekColors.darkTextMuted : TekColors.lightTextMuted;
    final primary = isDark ? TekColors.primary : TekColors.primaryDark;

    final accent = TekColors.secondary;

    final colorScheme = (isDark ? ColorScheme.dark() : ColorScheme.light()).copyWith(
      primary: primary,
      onPrimary: isDark ? TekColors.darkBackground : Colors.white,
      secondary: accent,
      onSecondary: isDark ? TekColors.darkBackground : TekColors.lightTextPrimary,
      secondaryContainer: isDark
          ? accent
          : accent.withValues(alpha: 0.22),
      onSecondaryContainer: isDark ? Colors.white : TekColors.lightTextPrimary,
      error: TekColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: muted,
      surfaceContainerHighest: elevated,
      outline: border,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: colorScheme,
      textTheme: AppTypography.textTheme(brightness),
      iconTheme: IconThemeData(color: onSurface),
      primaryIconTheme: IconThemeData(color: primary),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: isDark ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0 : 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected) ? primary : muted,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.sourceSans3(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? primary : muted,
          );
        }),
        height: 64,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.15),
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: muted),
        selectedLabelTextStyle: GoogleFonts.sourceSans3(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        unselectedLabelTextStyle: GoogleFonts.sourceSans3(
          fontSize: 12,
          color: muted,
        ),
        labelType: NavigationRailLabelType.all,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevated,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: TekColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: GoogleFonts.sourceSans3(fontSize: 14, color: muted),
        hintStyle: GoogleFonts.sourceSans3(fontSize: 14, color: muted),
        floatingLabelStyle: GoogleFonts.sourceSans3(fontSize: 14, color: primary),
        helperStyle: GoogleFonts.sourceSans3(fontSize: 12, color: muted),
        errorStyle: GoogleFonts.sourceSans3(fontSize: 12, color: TekColors.error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: isDark ? TekColors.darkBackground : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.sourceSans3(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.sourceSans3(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: elevated,
        disabledColor: elevated.withValues(alpha: 0.5),
        selectedColor: accent,
        secondarySelectedColor: accent,
        checkmarkColor: isDark ? Colors.white : TekColors.lightTextPrimary,
        showCheckmark: true,
        labelStyle: GoogleFonts.sourceSans3(fontSize: 12, color: onSurface),
        secondaryLabelStyle: GoogleFonts.sourceSans3(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : TekColors.lightTextPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: onSurface,
        iconColor: muted,
        titleTextStyle: GoogleFonts.sourceSans3(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: onSurface,
        ),
        subtitleTextStyle: GoogleFonts.sourceSans3(fontSize: 14, color: muted),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: GoogleFonts.sourceSans3(fontSize: 14, color: onSurface),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: GoogleFonts.sourceSans3(fontSize: 14, color: muted),
          hintStyle: GoogleFonts.sourceSans3(fontSize: 14, color: muted),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        textColor: onSurface,
        collapsedTextColor: muted,
        iconColor: muted,
        collapsedIconColor: muted,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
      ),
      searchBarTheme: SearchBarThemeData(
        textStyle: WidgetStatePropertyAll(
          GoogleFonts.sourceSans3(fontSize: 14, color: onSurface),
        ),
        hintStyle: WidgetStatePropertyAll(
          GoogleFonts.sourceSans3(fontSize: 14, color: muted),
        ),
        backgroundColor: WidgetStatePropertyAll(elevated),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        overlayColor: WidgetStatePropertyAll(primary.withValues(alpha: 0.08)),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: GoogleFonts.sourceSans3(fontSize: 12, color: onSurface),
        decoration: BoxDecoration(
          color: elevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(elevated),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        textStyle: GoogleFonts.sourceSans3(fontSize: 14, color: onSurface),
        surfaceTintColor: Colors.transparent,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return isDark ? TekColors.darkBackground : Colors.white;
            }
            return onSurface;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }
            return elevated;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: elevated,
        contentTextStyle: GoogleFonts.sourceSans3(color: onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        contentTextStyle: GoogleFonts.sourceSans3(fontSize: 14, color: muted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor:
            isDark ? TekColors.darkTextMuted : TekColors.lightTextMuted,
        indicatorColor: primary,
        labelStyle: GoogleFonts.sourceSans3(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.sourceSans3(),
        dividerColor: border,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          primary.withValues(alpha: isDark ? 0.45 : 0.35),
        ),
        trackColor: WidgetStatePropertyAll(
          border.withValues(alpha: 0.5),
        ),
        trackBorderColor: WidgetStatePropertyAll(border.withValues(alpha: 0.3)),
        radius: const Radius.circular(6),
        thickness: WidgetStatePropertyAll(8),
        crossAxisMargin: 2,
        mainAxisMargin: 2,
        interactive: true,
      ),
      splashFactory: InkSparkle.splashFactory,
      hoverColor: primary.withValues(alpha: 0.06),
      focusColor: primary.withValues(alpha: 0.1),
      highlightColor: primary.withValues(alpha: 0.08),
      extensions: [TekThemeExtension(isDark: isDark, border: border, elevated: elevated)],
    );
  }
}

@immutable
class TekThemeExtension extends ThemeExtension<TekThemeExtension> {
  const TekThemeExtension({
    required this.isDark,
    required this.border,
    required this.elevated,
  });

  final bool isDark;
  final Color border;
  final Color elevated;

  Color get gridLine =>
      isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);

  Color get axisLine =>
      isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.12);

  @override
  TekThemeExtension copyWith({bool? isDark, Color? border, Color? elevated}) {
    return TekThemeExtension(
      isDark: isDark ?? this.isDark,
      border: border ?? this.border,
      elevated: elevated ?? this.elevated,
    );
  }

  @override
  TekThemeExtension lerp(ThemeExtension<TekThemeExtension>? other, double t) {
    if (other is! TekThemeExtension) return this;
    return TekThemeExtension(
      isDark: t < 0.5 ? isDark : other.isDark,
      border: Color.lerp(border, other.border, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
    );
  }
}

TekThemeExtension tekTheme(BuildContext context) {
  return Theme.of(context).extension<TekThemeExtension>()!;
}
