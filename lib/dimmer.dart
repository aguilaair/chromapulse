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

/// Output levels in 0..1, after the dimmer curve.
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

  factory LightLevels.fromDmx(ArtnetState dmx, SettingsState settings) {
    final curve = settings.dimmerCurve;
    double level(DmxChannel channel) => channel.value.clamp(0, 255) / 255;
    double colour(DmxChannel channel) =>
        settings.curveRgb ? curve.apply(level(channel)) : level(channel);
    return LightLevels(
      red: colour(dmx.red),
      green: colour(dmx.green),
      blue: colour(dmx.blue),
      brightness: settings.use4Channels
          ? curve.apply(level(dmx.brightness))
          : null,
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
