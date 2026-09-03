import 'package:flutter/material.dart';

/// Visual tokens copied from DicomFlow web `styles.css` (online site).
/// Do not use the stale OLED design-system MASTER.md.
abstract final class AppColors {
  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFF3B82F6);
  static const primaryDark = Color(0xFF1D4ED8);
  static const accent = Color(0xFFF97316);
  static const accentDark = Color(0xFFFB923C);

  static const bgLight = Color(0xFFF8FAFC);
  static const cardLight = Color(0xFFFFFFFF);
  static const borderLight = Color(0xFFE2E8F0);
  static const textLight = Color(0xFF0F172A);
  static const mutedLight = Color(0xFF475569);
  static const muted2Light = Color(0xFF94A3B8);
  static const successLight = Color(0xFF00A544);
  static const dangerLight = Color(0xFFE40014);
  static const trackLight = Color(0xFFE2E8F0);

  static const bgDark = Color(0xFF0B0B10);
  static const cardDark = Color(0xFF121218);
  static const borderDark = Color(0xFF1E293B);
  static const textDark = Color(0xFFF8FAFC);
  static const mutedDark = Color(0xFF94A3B8);
  static const muted2Dark = Color(0xFF64748B);
  static const successDark = Color(0xFF05DF72);
  static const dangerDark = Color(0xFFFF6568);
  static const trackDark = Color(0xFF1E293B);
}

abstract final class AppRadii {
  static const card = 16.0;
  static const control = 12.0;
}

abstract final class AppLayout {
  static const navBarHeight = 68.0;
  static const desktopBreakpoint = 720.0;

  static bool isDesktopShell(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= desktopBreakpoint;
  }

  static double listBottomInset(BuildContext context) {
    final pad = 16 + MediaQuery.paddingOf(context).bottom;
    if (isDesktopShell(context)) return pad;
    return pad + navBarHeight;
  }
}

abstract final class AppFonts {
  static const fallback = <String>[
    'PingFang SC',
    'Hiragino Sans GB',
    'Noto Sans SC',
    'Microsoft YaHei',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];
}

ThemeData buildAppTheme({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;
  final primary = isDark ? AppColors.primaryLight : AppColors.primary;
  final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
  final card = isDark ? AppColors.cardDark : AppColors.cardLight;
  final text = isDark ? AppColors.textDark : AppColors.textLight;
  final muted = isDark ? AppColors.mutedDark : AppColors.mutedLight;
  final border = isDark ? AppColors.borderDark : AppColors.borderLight;
  final danger = isDark ? AppColors.dangerDark : AppColors.dangerLight;
  final success = isDark ? AppColors.successDark : AppColors.successLight;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: Colors.white,
    secondary: isDark ? AppColors.accentDark : AppColors.accent,
    onSecondary: Colors.white,
    error: danger,
    onError: Colors.white,
    surface: card,
    onSurface: text,
    outline: border,
    surfaceTint: Colors.transparent,
  );

  final textTheme = ThemeData(brightness: brightness).textTheme.apply(
    bodyColor: text,
    displayColor: text,
    fontFamilyFallback: AppFonts.fallback,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    textTheme: textTheme,
    canvasColor: bg,
    dividerColor: border,
    appBarTheme: AppBarTheme(
      backgroundColor: bg.withValues(alpha: 0.8),
      foregroundColor: text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card.withValues(alpha: 0.92),
      indicatorColor: primary.withValues(alpha: 0.12),
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? primary : muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? primary : muted, size: 22);
      }),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: border),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: card,
      indicatorColor: primary.withValues(alpha: 0.14),
      selectedIconTheme: IconThemeData(color: primary, size: 24),
      unselectedIconTheme: IconThemeData(color: muted, size: 24),
      selectedLabelTextStyle: TextStyle(
        color: primary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: muted,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(140, 48),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: primary.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(140, 44),
        foregroundColor: text,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: primary.withValues(alpha: 0.14),
      backgroundColor: bg,
      side: BorderSide(color: border),
      showCheckmark: false,
      labelStyle: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: primary, width: 1.4),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primary;
        return Colors.transparent;
      }),
      side: BorderSide(color: border, width: 1.4),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? AppColors.cardDark : AppColors.textLight,
      contentTextStyle: TextStyle(color: isDark ? text : Colors.white),
    ),
    extensions: [
      DicomFlowTokens(
        muted: muted,
        muted2: isDark ? AppColors.muted2Dark : AppColors.muted2Light,
        success: success,
        glass: isDark
            ? const Color(0xB8121218)
            : const Color(0xB8FFFFFF),
        glassBorder: isDark
            ? const Color(0x14FFFFFF)
            : const Color(0x140F172A),
        track: isDark ? AppColors.trackDark : AppColors.trackLight,
        accent: isDark ? AppColors.accentDark : AppColors.accent,
      ),
    ],
  );
}

@immutable
class DicomFlowTokens extends ThemeExtension<DicomFlowTokens> {
  const DicomFlowTokens({
    required this.muted,
    required this.muted2,
    required this.success,
    required this.glass,
    required this.glassBorder,
    required this.track,
    required this.accent,
  });

  final Color muted;
  final Color muted2;
  final Color success;
  final Color glass;
  final Color glassBorder;
  final Color track;
  final Color accent;

  static DicomFlowTokens of(BuildContext context) {
    return Theme.of(context).extension<DicomFlowTokens>()!;
  }

  @override
  DicomFlowTokens copyWith({
    Color? muted,
    Color? muted2,
    Color? success,
    Color? glass,
    Color? glassBorder,
    Color? track,
    Color? accent,
  }) {
    return DicomFlowTokens(
      muted: muted ?? this.muted,
      muted2: muted2 ?? this.muted2,
      success: success ?? this.success,
      glass: glass ?? this.glass,
      glassBorder: glassBorder ?? this.glassBorder,
      track: track ?? this.track,
      accent: accent ?? this.accent,
    );
  }

  @override
  DicomFlowTokens lerp(ThemeExtension<DicomFlowTokens>? other, double t) {
    if (other is! DicomFlowTokens) return this;
    return DicomFlowTokens(
      muted: Color.lerp(muted, other.muted, t)!,
      muted2: Color.lerp(muted2, other.muted2, t)!,
      success: Color.lerp(success, other.success, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      track: Color.lerp(track, other.track, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}
