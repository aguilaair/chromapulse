import 'dart:ui' show Color, lerpDouble;

import 'package:flutter/foundation.dart' show listEquals;

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

/// Channel levels in 0..1, one colour per zone. Fades interpolate raw DMX
/// levels and apply the curve on the way out, so the curve also shapes the
/// fade. [brightness] is null when no brightness channel is patched.
class LightLevels {
  final List<Color> zones;
  final double? brightness;

  const LightLevels({required this.zones, this.brightness});

  factory LightLevels.fromDmx(ArtnetState dmx, {required bool brightness}) {
    double level(int value) => value.clamp(0, 255) / 255;
    return LightLevels(
      zones: [
        for (final zone in dmx.zones)
          Color.from(
            alpha: 1,
            red: level(zone.red),
            green: level(zone.green),
            blue: level(zone.blue),
          ),
      ],
      brightness: brightness ? level(dmx.brightness.value) : null,
    );
  }

  LightLevels output(SettingsState settings) {
    final curve = settings.dimmerCurve;
    double colour(double level) =>
        settings.curveRgb ? curve.apply(level) : level;
    final brightness = this.brightness;
    return LightLevels(
      zones: [
        for (final zone in zones)
          Color.from(
            alpha: 1,
            red: colour(zone.r),
            green: colour(zone.g),
            blue: colour(zone.b),
          ),
      ],
      brightness: brightness == null ? null : curve.apply(brightness),
    );
  }

  /// A zone missing from [a] fades in from black.
  static LightLevels lerp(LightLevels a, LightLevels b, double t) {
    return LightLevels(
      zones: [
        for (var z = 0; z < b.zones.length; z++)
          Color.lerp(
            z < a.zones.length ? a.zones[z] : const Color(0xFF000000),
            b.zones[z],
            t,
          )!,
      ],
      brightness: a.brightness == null || b.brightness == null
          ? b.brightness
          : lerpDouble(a.brightness, b.brightness, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LightLevels &&
      listEquals(other.zones, zones) &&
      other.brightness == brightness;

  @override
  int get hashCode => Object.hash(Object.hashAll(zones), brightness);
}
