import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The two typefaces, and the Arabic one that has to stand in for both.
///
/// ## Why this exists
///
/// Bulkr's voice is Anton for headings and Inter for everything else, and it
/// called `GoogleFonts.anton` and `GoogleFonts.inter` directly at five hundred
/// call sites. **Anton has no Arabic glyphs.** Not a sparse set — none. So in
/// Arabic every heading in the app would have fallen back to whatever the
/// platform picked, which means the app's entire display voice would have been
/// chosen by neither the designer nor anybody else.
///
/// Inter does cover Arabic, but mixing a Latin-first face with a real Arabic
/// one across the same screen reads as two apps stapled together.
///
/// So in Arabic both roles are Cairo, which was drawn for Arabic and has a
/// Latin companion good enough for the numbers that sit next to it — and
/// numbers are on nearly every screen in a nutrition app.
///
/// ## Weight carries what the typeface cannot
///
/// Anton has one weight and it is heavy; that heaviness is what makes a Bulkr
/// heading look like a Bulkr heading. Cairo has a range, so [display] asks for
/// 800 by default and keeps whatever weight a call site passed. Without that,
/// Arabic headings would be the right typeface at the wrong volume, which is a
/// subtler way of looking wrong.
///
/// ## Why a static flag and not a `BuildContext`
///
/// Every one of those five hundred call sites is inside a `TextStyle`
/// expression, most of them in `const`-adjacent positions, and threading a
/// context through all of them is a far larger change than this one. The flag
/// is set once per build of the root, from the locale easy_localization
/// already knows — see `main.dart`. It is write-once-per-locale and read
/// everywhere, which is the shape a theme would have if the call sites used
/// one.
class AppFonts {
  const AppFonts._();

  static bool _arabic = false;

  /// Whether text should be set in Cairo. Called from the root's builder, so
  /// it is already correct before anything below it lays out.
  static void useArabic(bool value) => _arabic = value;

  static bool get isArabic => _arabic;

  /// Headings. Anton in Latin, Cairo at display weight in Arabic.
  static TextStyle display({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    if (!_arabic) {
      return GoogleFonts.anton(
        textStyle: textStyle,
        color: color,
        backgroundColor: backgroundColor,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        wordSpacing: wordSpacing,
        textBaseline: textBaseline,
        height: height,
        locale: locale,
        foreground: foreground,
        background: background,
        shadows: shadows,
        fontFeatures: fontFeatures,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        decorationThickness: decorationThickness,
      );
    }

    return GoogleFonts.cairo(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      // Anton's single weight is heavy, and that is the heading's whole
      // character. Cairo has to be asked.
      fontWeight: fontWeight ?? FontWeight.w800,
      fontStyle: fontStyle,
      // Letter spacing is a Latin display trick. Arabic is joined: spacing it
      // out does not look airy, it looks broken.
      letterSpacing: _arabic ? null : letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  /// Everything else. Inter in Latin, Cairo in Arabic.
  static TextStyle body({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    final TextStyle Function({
      TextStyle? textStyle,
      Color? color,
      Color? backgroundColor,
      double? fontSize,
      FontWeight? fontWeight,
      FontStyle? fontStyle,
      double? letterSpacing,
      double? wordSpacing,
      TextBaseline? textBaseline,
      double? height,
      Locale? locale,
      Paint? foreground,
      Paint? background,
      List<Shadow>? shadows,
      List<FontFeature>? fontFeatures,
      TextDecoration? decoration,
      Color? decorationColor,
      TextDecorationStyle? decorationStyle,
      double? decorationThickness,
    }) face = _arabic ? GoogleFonts.cairo : GoogleFonts.inter;

    return face(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: _arabic ? null : letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }
}
