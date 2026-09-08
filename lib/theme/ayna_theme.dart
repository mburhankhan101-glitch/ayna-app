import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ayna_colors.dart';
import 'ayna_tokens.dart';
import 'ayna_typography.dart';

/// Assembles the Warm Mirror theme.
///
/// ## On dark mode
///
/// There is deliberately no dark theme here. Warm Mirror is a light-committed
/// direction — its identity is cream and clay — and mechanically inverting it
/// produces mud, not a dark variant. A real dark palette is a design pass
/// (which greys, which clay at which luminance, what happens to the heatmap
/// over a dark ground), not a code change.
///
/// So [AynaApp] pins `themeMode: ThemeMode.light`. That is a decision to
/// revisit, not an oversight: without the pin, a phone in dark mode gets
/// Flutter's default dark theme and the app looks broken.
abstract final class AynaTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AynaColors.clay,
      onPrimary: AynaColors.onClay,
      primaryContainer: AynaColors.claySoft,
      onPrimaryContainer: AynaColors.clayDark,
      secondary: AynaColors.olive,
      onSecondary: AynaColors.oliveTint,
      secondaryContainer: AynaColors.oliveTint,
      onSecondaryContainer: AynaColors.oliveDeep,
      tertiary: AynaColors.clayDark,
      onTertiary: AynaColors.onClay,
      // No `error: red`. Nothing in this product is an error state in the
      // alarming sense — a severe reading is information, not a failure, and
      // the referral card is olive precisely so it never reads as an alert.
      // Form validation still needs a colour, so clayDark serves; it is the
      // strongest thing in the palette without importing a warning red.
      error: AynaColors.clayDark,
      onError: AynaColors.onClay,
      surface: AynaColors.surface,
      onSurface: AynaColors.ink,
      surfaceContainerLowest: AynaColors.surface,
      surfaceContainerLow: AynaColors.cream,
      surfaceContainer: AynaColors.clayTint,
      surfaceContainerHigh: AynaColors.surfaceSunk,
      surfaceContainerHighest: AynaColors.surfaceSunk,
      onSurfaceVariant: AynaColors.inkMuted,
      outline: AynaColors.border,
      outlineVariant: AynaColors.divider,
      shadow: Color(0x1A3A322A),
      scrim: Color(0x99241D18),
      inverseSurface: AynaColors.ink,
      onInverseSurface: AynaColors.cream,
      inversePrimary: AynaColors.claySoft,
    );

    const tokens = AynaTokens.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AynaColors.cream,
      fontFamily: AynaType.family,
      textTheme: AynaType.textTheme,
      extensions: const [tokens],

      // Every tappable meets the 48px floor, enforced here rather than
      // remembered per widget.
      materialTapTargetSize: MaterialTapTargetSize.padded,

      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: AynaColors.cream,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AynaColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AynaType.titleLarge,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AynaColors.clay,
          foregroundColor: AynaColors.onClay,
          disabledBackgroundColor: AynaColors.surfaceSunk,
          disabledForegroundColor: AynaColors.inkFaint,
          minimumSize: Size.fromHeight(tokens.minTouch),
          elevation: 0,
          textStyle: AynaType.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusMd),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AynaColors.clay,
          backgroundColor: AynaColors.surface,
          minimumSize: Size.fromHeight(tokens.minTouch),
          side: const BorderSide(color: AynaColors.clay, width: 1.5),
          textStyle: AynaType.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusMd),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AynaColors.inkSubtle,
          minimumSize: Size(tokens.minTouch, tokens.space11),
          textStyle: AynaType.titleSmall,
        ),
      ),

      cardTheme: CardThemeData(
        color: AynaColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusLg),
          side: const BorderSide(color: AynaColors.border),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AynaColors.surface,
        constraints: BoxConstraints(minHeight: tokens.minTouch),
        contentPadding: EdgeInsets.symmetric(
          horizontal: tokens.space4,
          vertical: tokens.space3,
        ),
        hintStyle: AynaType.bodyLarge.copyWith(color: AynaColors.inkFaint),
        border: _inputBorder(tokens.radiusMd, AynaColors.border),
        enabledBorder: _inputBorder(tokens.radiusMd, AynaColors.border),
        focusedBorder: _inputBorder(
          tokens.radiusMd,
          AynaColors.clay,
          width: 1.5,
        ),
        errorBorder: _inputBorder(tokens.radiusMd, AynaColors.clayDark),
        focusedErrorBorder: _inputBorder(
          tokens.radiusMd,
          AynaColors.clayDark,
          width: 1.5,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AynaColors.divider,
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AynaColors.clayTint,
        selectedColor: AynaColors.clay,
        labelStyle: AynaType.titleSmall.copyWith(color: AynaColors.inkSubtle),
        secondaryLabelStyle: AynaType.titleSmall.copyWith(
          color: AynaColors.onClay,
        ),
        side: BorderSide.none,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space3,
          vertical: tokens.space2,
        ),
        shape: const StadiumBorder(),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AynaColors.onClay
              : AynaColors.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AynaColors.clay
              : AynaColors.border,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AynaColors.clay,
        linearTrackColor: AynaColors.severityNone,
        circularTrackColor: AynaColors.severityNone,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AynaColors.surface,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => AynaType.labelSmall.copyWith(
            letterSpacing: 0,
            fontSize: 10,
            color: s.contains(WidgetState.selected)
                ? AynaColors.clay
                : AynaColors.inkFaint,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 22,
            color: s.contains(WidgetState.selected)
                ? AynaColors.clay
                : AynaColors.inkFaint,
          ),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AynaColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.radiusXl),
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AynaColors.ink,
        contentTextStyle: AynaType.bodyMedium.copyWith(color: AynaColors.cream),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(
    double r,
    Color c, {
    double width = 1,
  }) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(r),
    borderSide: BorderSide(color: c, width: width),
  );
}
