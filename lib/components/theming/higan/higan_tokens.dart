import 'package:flutter/material.dart';
import 'package:sbn/font_fallbacks.dart';

/// Higan design tokens: colors for Night (dark) and Paper (light).
///
/// Read them with `context.higan` or [HiganColors.of].
@immutable
class HiganColors extends ThemeExtension<HiganColors> {
  const new({
    required this.brightness,
    required this.bg,
    required this.surface1,
    required this.surface2,
    required this.hairline,
    required this.hairlineStrong,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.pagePaper,
    required this.thumbPaper,
    required this.ember,
    this.higan = const Color(0xFFD0283A),
    this.stamen = const Color(0xFFE2B46C),
    this.stem = const Color(0xFF7B1A24),
  });

  final Brightness brightness;

  /// App background.
  final Color bg;

  /// Cards, folder stacks, sheets.
  final Color surface1;

  /// Selected segments, menus, floating pills.
  final Color surface2;

  /// 1px borders and dividers.
  final Color hairline, hairlineStrong;

  /// "bone" / "ink", "ash", "smoke".
  final Color text, textSecondary, textTertiary;

  /// The one red: new note, active tab dot, selected tool dot.
  final Color higan;

  /// Gold for tiny details: sync dot, lily anthers.
  final Color stamen;

  /// Lily stem.
  final Color stem;

  /// Editor page background.
  final Color pagePaper;

  /// Note thumbnail background.
  final Color thumbPaper;

  /// Center color of the soft red glow in the top-left of home screens.
  final Color ember;

  bool get isNight => brightness == .dark;

  static const night = HiganColors(
    brightness: .dark,
    bg: Color(0xFF0A0A0B),
    surface1: Color(0xFF111113),
    surface2: Color(0xFF18181B),
    hairline: Color(0x12FFFFFF), // 0.07
    hairlineStrong: Color(0x1FFFFFFF), // 0.12
    text: Color(0xFFECEAE5),
    textSecondary: Color(0xFF8B8883),
    textTertiary: Color(0xFF55534F),
    pagePaper: Color(0xFFF4F2ED),
    thumbPaper: Color(0xFFE6E3DC),
    ember: Color(0x5CD0283A), // 0.36
  );

  static const paper = HiganColors(
    brightness: .light,
    bg: Color(0xFFF1EFEA),
    surface1: Color(0xFFF8F7F3),
    surface2: Color(0xFFFFFFFF),
    hairline: Color(0x14141210), // 0.08
    hairlineStrong: Color(0x24141210), // 0.14
    text: Color(0xFF151413),
    textSecondary: Color(0xFF6E6A65),
    textTertiary: Color(0xFFA6A29B),
    pagePaper: Color(0xFFFBFAF7),
    thumbPaper: Color(0xFFFBFAF7),
    ember: Color(0x1FD0283A), // 0.12
  );

  /// The theme's [HiganColors], or [night]/[paper] by brightness
  /// if the theme doesn't have them (e.g. in tests).
  static HiganColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<HiganColors>() ??
        (theme.brightness == .dark ? night : paper);
  }

  /// Shadow under paper thumbnails/pages. Night: deep, Paper: faint.
  List<BoxShadow> get paperShadow => isNight
      ? const [
          BoxShadow(color: Color(0x0AFFFFFF), spreadRadius: 1),
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 14),
            blurRadius: 30,
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x0F141210),
            offset: Offset(0, 6),
            blurRadius: 16,
          ),
        ];

  /// Floating glass (toolbars, HUD): near-opaque, so it reads the same
  /// over the dark surround, a paper page or a black page.
  Color get glass => surface2.withValues(alpha: 0.95);

  /// The red for text and small marks on text: [higan] is too dark to read
  /// on Night surfaces, so it's lightened there.
  Color get higanText => isNight ? const Color(0xFFE8505F) : higan;

  /// Gold for small UI dots (e.g. "synced"): [stamen] vanishes on Paper,
  /// so it's darkened there. The lily keeps [stamen].
  Color get stamenMark => isNight ? stamen : const Color(0xFFA87A2E);

  /// A recessed well, e.g. behind a folder's stack of pages. In Paper it's
  /// a little darker than [bg] so the pages stand off it.
  Color get well => isNight ? surface1 : const Color(0xFFECEAE4);

  @override
  HiganColors copyWith({
    Brightness? brightness,
    Color? bg,
    Color? surface1,
    Color? surface2,
    Color? hairline,
    Color? hairlineStrong,
    Color? text,
    Color? textSecondary,
    Color? textTertiary,
    Color? higan,
    Color? stamen,
    Color? stem,
    Color? pagePaper,
    Color? thumbPaper,
    Color? ember,
  }) => HiganColors(
    brightness: brightness ?? this.brightness,
    bg: bg ?? this.bg,
    surface1: surface1 ?? this.surface1,
    surface2: surface2 ?? this.surface2,
    hairline: hairline ?? this.hairline,
    hairlineStrong: hairlineStrong ?? this.hairlineStrong,
    text: text ?? this.text,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    higan: higan ?? this.higan,
    stamen: stamen ?? this.stamen,
    stem: stem ?? this.stem,
    pagePaper: pagePaper ?? this.pagePaper,
    thumbPaper: thumbPaper ?? this.thumbPaper,
    ember: ember ?? this.ember,
  );

  @override
  HiganColors lerp(HiganColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return HiganColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: c(bg, other.bg),
      surface1: c(surface1, other.surface1),
      surface2: c(surface2, other.surface2),
      hairline: c(hairline, other.hairline),
      hairlineStrong: c(hairlineStrong, other.hairlineStrong),
      text: c(text, other.text),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      higan: c(higan, other.higan),
      stamen: c(stamen, other.stamen),
      stem: c(stem, other.stem),
      pagePaper: c(pagePaper, other.pagePaper),
      thumbPaper: c(thumbPaper, other.thumbPaper),
      ember: c(ember, other.ember),
    );
  }
}

extension HiganContext on BuildContext {
  HiganColors get higan => HiganColors.of(this);
}

/// Higan text styles. Sans styles follow the theme's font
/// (Geist, or Atkinson Hyperlegible if enabled); labels are always mono.
abstract final class HiganText {
  static const sans = 'Geist';
  static const mono = 'GeistMono';

  /// Big light title, e.g. "Folders". 40 on tablet/desktop, ~34 on phones.
  static TextStyle title(BuildContext context, {double size = 40}) =>
      _sans(context).copyWith(
        fontSize: size,
        fontWeight: .w300,
        letterSpacing: -0.025 * size,
        height: 1.05,
        color: context.higan.text,
      );

  /// Readable text: note titles (15), rows (15.5), paragraphs (14).
  static TextStyle body(
    BuildContext context, {
    double size = 15,
    FontWeight weight = .w400,
    Color? color,
  }) => _sans(context).copyWith(
    fontSize: size,
    fontWeight: weight,
    letterSpacing: -0.005 * size,
    height: 1.35,
    color: color ?? context.higan.text,
  );

  /// Tiny mono readout. Uppercase the string yourself (or use HiganLabel).
  static TextStyle label(
    BuildContext context, {
    double size = 11,
    Color? color,
    double tracking = 0.14,
  }) => TextStyle(
    fontFamily: mono,
    fontFamilyFallback: ntsMonoFontFallbacks,
    fontSize: size,
    fontWeight: .w400,
    letterSpacing: tracking * size,
    height: 1.2,
    color: color ?? context.higan.textSecondary,
  );

  static TextStyle _sans(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
}

abstract final class HiganRadius {
  /// Note page thumbnails / small list thumbnails.
  static const paper = 4.0;

  /// Note cards in the gallery, editor pages.
  static const page = 6.0;

  /// Cards and folder stacks.
  static const card = 16.0;

  /// Floating glass pills (height 50).
  static const bar = 25.0;

  /// Stadium.
  static const pill = 999.0;
}

abstract final class HiganSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 18.0;
  static const xl = 26.0;
  static const xxl = 40.0;

  /// Horizontal page padding: phone, tablet, desktop content.
  static const gutterPhone = 20.0;
  static const gutterTablet = 40.0;
  static const gutterDesktop = 44.0;

  /// Desktop sidebar width.
  static const sidebar = 236.0;
}

abstract final class HiganTap {
  /// Smallest tap target on touch screens (Apple HIG).
  static const min = 44.0;

  /// Fingers, not a pointer: tap targets grow to [min].
  static bool isTouch(BuildContext context) =>
      switch (Theme.of(context).platform) {
        .iOS || .android || .fuchsia => true,
        .macOS || .windows || .linux => false,
      };
}

abstract final class HiganMotion {
  /// cubic-bezier(.2,.8,.2,1): used for hovers, fans and lifts.
  static const curve = Cubic(0.2, 0.8, 0.2, 1);
  static const fast = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 350);
  static const slow = Duration(milliseconds: 500);
}
