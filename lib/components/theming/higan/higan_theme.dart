import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/data/prefs.dart';
import 'package:sbn/font_fallbacks.dart';

/// Builds the Material 3 [ThemeData] for Night (dark) and Paper (light).
abstract final class HiganTheme {
  static ThemeData night(TargetPlatform platform) =>
      build(HiganColors.night, platform);
  static ThemeData paper(TargetPlatform platform) =>
      build(HiganColors.paper, platform);

  static ThemeData build(HiganColors c, TargetPlatform platform) {
    final fontFamily = stows.hyperlegibleFont.value
        ? 'AtkinsonHyperlegibleNext'
        : HiganText.sans;
    const white = Color(0xFFFFFFFF);
    final wash = c.text.withValues(alpha: 0.05);

    final colorScheme = ColorScheme(
      brightness: c.brightness,
      primary: c.higan,
      onPrimary: white,
      primaryContainer: c.surface2,
      onPrimaryContainer: c.text,
      secondary: c.textSecondary,
      onSecondary: c.bg,
      secondaryContainer: c.surface2,
      onSecondaryContainer: c.text,
      tertiary: c.stamen,
      onTertiary: const Color(0xFF151413),
      error: c.higan,
      onError: white,
      surface: c.bg,
      onSurface: c.text,
      onSurfaceVariant: c.textSecondary,
      surfaceDim: c.bg,
      surfaceBright: c.surface2,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.surface1,
      surfaceContainer: c.surface1,
      surfaceContainerHigh: c.surface2,
      surfaceContainerHighest: c.surface2,
      outline: c.hairlineStrong,
      outlineVariant: c.hairline,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
      inverseSurface: c.text,
      onInverseSurface: c.bg,
      inversePrimary: c.higan,
      surfaceTint: Colors.transparent,
    );

    TextStyle mono(double size, [Color? color]) => TextStyle(
      fontFamily: HiganText.mono,
      fontFamilyFallback: ntsMonoFontFallbacks,
      fontSize: size,
      letterSpacing: 0.12 * size,
      color: color,
    );
    TextStyle sans(double size, [Color? color, FontWeight weight = .w400]) =>
        TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: ntsSansSerifFontFallbacks,
          fontSize: size,
          fontWeight: weight,
          color: color,
        );

    RoundedRectangleBorder rounded(double radius, [Color? side]) =>
        RoundedRectangleBorder(
          borderRadius: .circular(radius),
          side: side == null ? BorderSide.none : BorderSide(color: side),
        );
    const stadium = StadiumBorder();
    WidgetStateProperty<T> states<T>(T selected, T otherwise) =>
        WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? selected : otherwise,
        );
    final overlay = WidgetStateProperty.resolveWith<Color?>(
      (s) => s.contains(WidgetState.pressed)
          ? c.text.withValues(alpha: 0.08)
          : s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)
          ? c.text.withValues(alpha: 0.04)
          : null,
    );
    // A visible keyboard focus ring (the overlay alone is too faint),
    // like HiganFocusRing. [WidgetState.focused] is set after touch too,
    // so check the highlight mode.
    final ring = BorderSide(color: c.text, width: 1.5);
    WidgetStateProperty<BorderSide?> focusSide([BorderSide? otherwise]) =>
        WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.focused) &&
                  FocusManager.instance.highlightMode == .traditional
              ? ring
              : otherwise,
        );
    final hairlineSide = BorderSide(color: c.hairlineStrong);

    final base = ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: colorScheme,
      platform: platform,
      fontFamily: fontFamily,
      fontFamilyFallback: ntsSansSerifFontFallbacks,
      extensions: [c],
    );
    final textTheme = base.textTheme
        .apply(bodyColor: c.text, displayColor: c.text)
        .copyWith(
          displayLarge: base.textTheme.displayLarge?.copyWith(
            fontWeight: .w300,
            color: c.text,
          ),
          displayMedium: base.textTheme.displayMedium?.copyWith(
            fontWeight: .w300,
            color: c.text,
          ),
          displaySmall: base.textTheme.displaySmall?.copyWith(
            fontWeight: .w300,
            color: c.text,
          ),
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontWeight: .w300,
            color: c.text,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: .w300,
            color: c.text,
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      cardColor: c.surface1,
      dividerColor: c.hairline,
      disabledColor: c.textTertiary,
      hintColor: c.textSecondary,
      splashColor: c.text.withValues(alpha: 0.06),
      highlightColor: c.text.withValues(alpha: 0.04),
      hoverColor: c.text.withValues(alpha: 0.03),
      focusColor: c.text.withValues(alpha: 0.08),
      splashFactory: InkRipple.splashFactory,
      iconTheme: IconThemeData(color: c.text, size: 20),
      cupertinoOverrideTheme: NoDefaultCupertinoThemeData(
        applyThemeToAll: true,
        primaryColor: c.higanText,
        barBackgroundColor: c.bg,
        scaffoldBackgroundColor: c.bg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: sans(17, c.text),
        iconTheme: IconThemeData(color: c.text, size: 20),
      ),
      cardTheme: CardThemeData(
        color: c.surface1,
        elevation: 0,
        margin: .zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: rounded(HiganRadius.card, c.hairline),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        tileColor: Colors.transparent,
        selectedColor: c.text,
        selectedTileColor: wash,
        titleTextStyle: sans(15, c.text),
        subtitleTextStyle: sans(13, c.textSecondary),
        leadingAndTrailingTextStyle: mono(11, c.textSecondary),
        contentPadding: const .symmetric(horizontal: 16),
        minVerticalPadding: 12,
      ),
      switchTheme: SwitchThemeData(
        // Bone/ink when on: red is kept for the one action that matters.
        thumbColor: states(c.bg, c.textSecondary),
        trackColor: states(c.text, c.surface2),
        trackOutlineColor: states(Colors.transparent, c.hairlineStrong),
        trackOutlineWidth: const WidgetStatePropertyAll(1),
        overlayColor: overlay,
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 2,
        activeTrackColor: c.text,
        inactiveTrackColor: c.hairlineStrong,
        thumbColor: c.text,
        overlayColor: c.text.withValues(alpha: 0.08),
        valueIndicatorColor: c.surface2,
        valueIndicatorTextStyle: mono(11, c.text),
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 6,
          elevation: 0,
          pressedElevation: 0,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        trackShape: const RoundedRectSliderTrackShape(),
        tickMarkShape: SliderTickMarkShape.noTickMark,
        // ignore: deprecated_member_use
        year2023: true,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(stadium),
          side: focusSide(hairlineSide),
          backgroundColor: states(c.surface2, Colors.transparent),
          foregroundColor: states(c.text, c.textSecondary),
          iconColor: states(c.text, c.textSecondary),
          overlayColor: overlay,
          textStyle: WidgetStatePropertyAll(mono(10.5)),
          visualDensity: .compact,
        ),
        selectedIcon: const SizedBox.shrink(),
      ),
      toggleButtonsTheme: ToggleButtonsThemeData(
        borderRadius: .circular(HiganRadius.pill),
        borderColor: c.hairlineStrong,
        selectedBorderColor: c.hairlineStrong,
        fillColor: c.surface2,
        color: c.textSecondary,
        selectedColor: c.text,
        textStyle: mono(10.5),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: rounded(HiganRadius.card, c.hairlineStrong),
        titleTextStyle: sans(20, c.text, .w300),
        contentTextStyle: sans(14, c.textSecondary),
        barrierColor: Colors.black.withValues(alpha: c.isNight ? 0.6 : 0.25),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface1,
        modalBackgroundColor: c.surface1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: c.hairlineStrong,
        shape: RoundedRectangleBorder(
          borderRadius: const .vertical(top: .circular(20)),
          side: BorderSide(color: c.hairline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surface2,
        contentTextStyle: sans(14, c.text),
        actionTextColor: c.text,
        behavior: .floating,
        elevation: 0,
        shape: rounded(12, c.hairlineStrong),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: const .all(.circular(6)),
          border: Border.all(color: c.hairlineStrong),
        ),
        textStyle: sans(12, c.text),
        padding: const .symmetric(horizontal: 10, vertical: 6),
        waitDuration: const Duration(milliseconds: 500),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface2,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: c.isNight ? 0.5 : 0.12),
        shape: rounded(12, c.hairlineStrong),
        textStyle: sans(14, c.text),
        labelTextStyle: WidgetStatePropertyAll(sans(14, c.text)),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surface2),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(4),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: c.isNight ? 0.5 : 0.12),
          ),
          shape: WidgetStatePropertyAll(rounded(12, c.hairlineStrong)),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: false,
        isDense: true,
        contentPadding: const .symmetric(horizontal: 14, vertical: 12),
        labelStyle: sans(14, c.textSecondary),
        floatingLabelStyle: sans(14, c.textSecondary),
        hintStyle: sans(14, c.textSecondary),
        helperStyle: sans(12, c.textSecondary),
        errorStyle: sans(12, c.higanText),
        prefixIconColor: c.textSecondary,
        suffixIconColor: c.textSecondary,
        border: OutlineInputBorder(
          borderRadius: const .all(.circular(12)),
          borderSide: BorderSide(color: c.hairlineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const .all(.circular(12)),
          borderSide: BorderSide(color: c.hairlineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const .all(.circular(12)),
          borderSide: BorderSide(color: c.textSecondary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const .all(.circular(12)),
          borderSide: BorderSide(color: c.higan),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: const .all(.circular(12)),
          borderSide: BorderSide(color: c.higan),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.higan,
        selectionColor: c.higan.withValues(alpha: 0.28),
        selectionHandleColor: c.higan,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.higan,
        foregroundColor: white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
        sizeConstraints: const BoxConstraints.tightFor(width: 58, height: 58),
        iconSize: 22,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(c.text),
          iconColor: WidgetStatePropertyAll(c.text),
          overlayColor: overlay,
          iconSize: const WidgetStatePropertyAll(20),
          side: focusSide(),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
      checkboxTheme: CheckboxThemeData(
        fillColor: states(c.higan, Colors.transparent),
        checkColor: const WidgetStatePropertyAll(white),
        side: BorderSide(color: c.textSecondary, width: 1.5),
        shape: rounded(4),
        overlayColor: overlay,
      ),
      radioTheme: RadioThemeData(
        fillColor: states(c.higan, c.textSecondary),
        overlayColor: overlay,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.text,
        linearTrackColor: c.hairline,
        circularTrackColor: Colors.transparent,
        stopIndicatorColor: Colors.transparent,
        // ignore: deprecated_member_use
        year2023: false,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.text,
          shape: stadium,
          textStyle: sans(14, null, .w500),
        ).copyWith(overlayColor: overlay, side: focusSide()),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.higan,
          foregroundColor: white,
          disabledBackgroundColor: c.surface2,
          disabledForegroundColor: c.textTertiary,
          shape: stadium,
          elevation: 0,
          minimumSize: const Size(0, 36),
          padding: const .symmetric(horizontal: 16),
          textStyle: sans(13.5, null, .w500),
        ).copyWith(side: focusSide()),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          shape: stadium,
          minimumSize: const Size(0, 36),
          padding: const .symmetric(horizontal: 16),
          textStyle: sans(13.5, null, .w500),
        ).copyWith(overlayColor: overlay, side: focusSide(hairlineSide)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.surface2,
          foregroundColor: c.text,
          elevation: 0,
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 36),
          textStyle: sans(13.5, null, .w500),
        ).copyWith(overlayColor: overlay, side: focusSide(hairlineSide)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: c.surface2,
        side: BorderSide(color: c.hairlineStrong),
        shape: stadium,
        labelStyle: sans(13, c.text),
        checkmarkColor: c.text,
      ),
      badgeTheme: BadgeThemeData(backgroundColor: c.higan, textColor: white),
      tabBarTheme: TabBarThemeData(
        labelColor: c.text,
        unselectedLabelColor: c.textSecondary,
        indicatorColor: c.higan,
        dividerColor: c.hairline,
        labelStyle: mono(11),
        unselectedLabelStyle: mono(11),
        overlayColor: overlay,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.bg,
        indicatorColor: c.surface2,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.bg,
        indicatorColor: c.surface2,
        elevation: 0,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(c.hairlineStrong),
      ),
    );
  }
}
