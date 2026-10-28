import 'dart:ui' show lerpDouble;

import 'package:chromapulse/providers/artnet.dart';
import 'package:chromapulse/providers/settings.dart';

enum DimmerCurve {
  linear('Linear'),
  square('Square law');

  const DimmerCurve(this.label);

  final String label;

  double apply(double level) => switch (this) {
    linear => level,
    square => level * level,
  };

  static DimmerCurve fromName(String? name) =>
      values.asNameMap()[name] ?? linear;
}

/// Channel levels in 0..1. Fades interpolate raw DMX levels and apply the
/// curve on the way out, so the curve also shapes the fade.
/// [brightness] is null when no brightness channel is patched.
class LightLevels {
  final double red;
  final double green;
  final double blue;
  final double? brightness;

  const LightLevels({
    required this.red,
    required this.green,
    required this.blue,
    this.brightness,
  });

  factory LightLevels.fromDmx(ArtnetState dmx, {required bool brightness}) {
    double level(DmxChannel channel) => channel.value.clamp(0, 255) / 255;
    return LightLevels(
      red: level(dmx.red),
      green: level(dmx.green),
      blue: level(dmx.blue),
      brightness: brightness ? level(dmx.brightness) : null,
    );
  }

  LightLevels output(SettingsState settings) {
    final curve = settings.dimmerCurve;
    double colour(double level) =>
        settings.curveRgb ? curve.apply(level) : level;
    final brightness = this.brightness;
    return LightLevels(
      red: colour(red),
      green: colour(green),
      blue: colour(blue),
      brightness: brightness == null ? null : curve.apply(brightness),
    );
  }

  static LightLevels lerp(LightLevels a, LightLevels b, double t) {
    return LightLevels(
      red: lerpDouble(a.red, b.red, t)!,
      green: lerpDouble(a.green, b.green, t)!,
      blue: lerpDouble(a.blue, b.blue, t)!,
      brightness: a.brightness == null || b.brightness == null
          ? b.brightness
          : lerpDouble(a.brightness, b.brightness, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LightLevels &&
      other.red == red &&
      other.green == green &&
      other.blue == blue &&
      other.brightness == brightness;

  @override
  int get hashCode => Object.hash(red, green, blue, brightness);
}
