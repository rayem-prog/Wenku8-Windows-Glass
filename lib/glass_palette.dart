import 'package:flutter/material.dart';

/// The Windows edition keeps book typography while its chrome uses a cooler,
/// clearer material. User-selected transparency still controls the tint alpha.
abstract final class WindowsGlass {
  static const blur = 14.0;
  static const opacity = .55;
  static const background = Color(0xFFF3F5F8);
  static const darkBackground = Color(0xFF131820);
  static Color tint(Brightness brightness, double opacity) =>
      brightness == Brightness.light
      ? Colors.white
      : Color.lerp(const Color(0xFFE5EBF5), const Color(0xFF1F2633), opacity)!;
}

/// Optional local material colors; other app surfaces keep their defaults.
@immutable
class GlassPalette extends ThemeExtension<GlassPalette> {
  const GlassPalette({required this.tint, required this.thumb});
  final Color tint, thumb;
  @override
  GlassPalette copyWith({Color? tint, Color? thumb}) =>
      GlassPalette(tint: tint ?? this.tint, thumb: thumb ?? this.thumb);
  @override
  GlassPalette lerp(GlassPalette? other, double t) => other == null
      ? this
      : GlassPalette(
          tint: Color.lerp(tint, other.tint, t)!,
          thumb: Color.lerp(thumb, other.thumb, t)!,
        );
}
