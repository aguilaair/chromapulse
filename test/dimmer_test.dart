import 'dart:ui';

import 'package:chromapulse/dimmer.dart';
import 'package:chromapulse/providers/artnet.dart';
import 'package:chromapulse/providers/settings.dart';
import 'package:flutter_test/flutter_test.dart';

Color rgb(double r, double g, double b) =>
    Color.from(alpha: 1, red: r, green: g, blue: b);

ArtnetState dmx({int r = 0, int g = 0, int b = 0, int brightness = 0}) {
  DmxChannel channel(int value) =>
      DmxChannel(channel: 1, value: value, universe: 1);
  return ArtnetState(
    ip: '',
    port: 0,
    zones: [RgbZone(r, g, b)],
    brightness: channel(brightness),
    torch: DmxChannel.unused,
    isBroadcasting: false,
  );
}

void main() {
  group('DimmerCurve', () {
    test('square law darkens the midpoint and keeps the ends', () {
      expect(DimmerCurve.square.apply(0), 0);
      expect(DimmerCurve.square.apply(0.5), 0.25);
      expect(DimmerCurve.square.apply(1), 1);
      expect(DimmerCurve.linear.apply(0.5), 0.5);
    });
  });

  group('LightLevels', () {
    final frame = dmx(r: 255, g: 51, b: 0, brightness: 51);

    test('fromDmx reads raw levels', () {
      expect(
        LightLevels.fromDmx(frame, brightness: true),
        LightLevels(zones: [rgb(1, 0.2, 0)], brightness: 0.2),
      );
      expect(LightLevels.fromDmx(frame, brightness: false).brightness, null);
    });

    test('linear output passes levels through', () {
      final raw = LightLevels.fromDmx(frame, brightness: true);
      expect(raw.output(SettingsState()), raw);
    });

    test('the curve applies to brightness only by default', () {
      final levels = LightLevels.fromDmx(
        frame,
        brightness: true,
      ).output(SettingsState(dimmerCurve: DimmerCurve.square));
      expect(levels.zones.single.g, 0.2);
      expect(levels.brightness, closeTo(0.04, 1e-9));
    });

    test('curveRgb applies the curve to colour too', () {
      final levels = LightLevels.fromDmx(
        frame,
        brightness: true,
      ).output(SettingsState(dimmerCurve: DimmerCurve.square, curveRgb: true));
      expect(levels.zones.single.r, 1);
      expect(levels.zones.single.g, closeTo(0.04, 1e-9));
    });

    test('a square-law fade is a quarter bright at its midpoint', () {
      final dark = LightLevels.fromDmx(dmx(), brightness: true);
      final full = LightLevels.fromDmx(dmx(brightness: 255), brightness: true);
      final mid = LightLevels.lerp(
        dark,
        full,
        0.5,
      ).output(SettingsState(dimmerCurve: DimmerCurve.square));
      expect(mid.brightness, 0.25);
    });
  });

  group('LightLevels.lerp', () {
    final black = LightLevels(zones: [rgb(0, 0, 0)], brightness: 0);
    final white = LightLevels(zones: [rgb(1, 1, 1)], brightness: 1);

    test('interpolates every channel', () {
      expect(
        LightLevels.lerp(black, white, 0.25),
        LightLevels(zones: [rgb(0.25, 0.25, 0.25)], brightness: 0.25),
      );
    });

    test('takes the target brightness when one side has none', () {
      final unpatched = LightLevels(zones: [rgb(0, 0, 0)]);
      expect(LightLevels.lerp(unpatched, white, 0.5).brightness, 1);
      expect(LightLevels.lerp(white, unpatched, 0.5).brightness, null);
    });
  });
  group('LightLevels with zones', () {
    test('each zone fades and takes the curve on its own', () {
      final from = LightLevels(zones: [rgb(0, 0, 0), rgb(1, 1, 1)]);
      final to = LightLevels(zones: [rgb(1, 0, 0), rgb(0, 0, 1)]);
      final mid = LightLevels.lerp(from, to, 0.5);
      expect(mid, LightLevels(zones: [rgb(0.5, 0, 0), rgb(0.5, 0.5, 1)]));
      expect(
        mid.output(
          SettingsState(dimmerCurve: DimmerCurve.square, curveRgb: true),
        ),
        LightLevels(zones: [rgb(0.25, 0, 0), rgb(0.25, 0.25, 1)]),
      );
    });

    test('a zone with no previous level fades in from black', () {
      final from = LightLevels(zones: [rgb(1, 1, 1)]);
      final to = LightLevels(zones: [rgb(1, 1, 1), rgb(1, 0, 0)]);
      expect(
        LightLevels.lerp(from, to, 0.5),
        LightLevels(zones: [rgb(1, 1, 1), rgb(0.5, 0, 0)]),
      );
    });

    test('fromDmx reads every zone', () {
      final frame = ArtnetState(
        ip: '',
        port: 0,
        zones: const [RgbZone(255, 0, 0), RgbZone(0, 0, 255)],
        brightness: DmxChannel.unused,
        torch: DmxChannel.unused,
        isBroadcasting: false,
      );
      expect(
        LightLevels.fromDmx(frame, brightness: false),
        LightLevels(zones: [rgb(1, 0, 0), rgb(0, 0, 1)]),
      );
    });
  });
}
