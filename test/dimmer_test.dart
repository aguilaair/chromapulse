import 'package:chromapulse/dimmer.dart';
import 'package:chromapulse/providers/artnet.dart';
import 'package:chromapulse/providers/settings.dart';
import 'package:flutter_test/flutter_test.dart';

ArtnetState dmx({int r = 0, int g = 0, int b = 0, int brightness = 0}) {
  DmxChannel channel(int value) =>
      DmxChannel(channel: 1, value: value, universe: 1);
  return ArtnetState(
    ip: '',
    port: 0,
    red: channel(r),
    green: channel(g),
    blue: channel(b),
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
        const LightLevels(red: 1, green: 0.2, blue: 0, brightness: 0.2),
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
      expect(levels.green, 0.2);
      expect(levels.brightness, closeTo(0.04, 1e-9));
    });

    test('curveRgb applies the curve to colour too', () {
      final levels = LightLevels.fromDmx(
        frame,
        brightness: true,
      ).output(SettingsState(dimmerCurve: DimmerCurve.square, curveRgb: true));
      expect(levels.red, 1);
      expect(levels.green, closeTo(0.04, 1e-9));
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
    const black = LightLevels(red: 0, green: 0, blue: 0, brightness: 0);
    const white = LightLevels(red: 1, green: 1, blue: 1, brightness: 1);

    test('interpolates every channel', () {
      expect(
        LightLevels.lerp(black, white, 0.25),
        const LightLevels(red: 0.25, green: 0.25, blue: 0.25, brightness: 0.25),
      );
    });

    test('takes the target brightness when one side has none', () {
      const unpatched = LightLevels(red: 0, green: 0, blue: 0);
      expect(LightLevels.lerp(unpatched, white, 0.5).brightness, 1);
      expect(LightLevels.lerp(white, unpatched, 0.5).brightness, null);
    });
  });
}
