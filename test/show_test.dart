import 'package:chromapulse/providers/artnet.dart';
import 'package:chromapulse/providers/providers.dart';
import 'package:chromapulse/providers/settings.dart';
import 'package:chromapulse/show.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const red = Color(0xFFFF0000);
const black = Color(0xFF000000);
const tick = Duration(milliseconds: 5);
const halfPeriod = Duration(microseconds: 166667);

class FakeSettings extends SettingsProvider {
  FakeSettings(this.initial);
  final SettingsState initial;

  @override
  SettingsState build() => initial;
}

class FakeArtnet extends ArtnetProvider {
  @override
  ArtnetState build() {
    DmxChannel zero() => DmxChannel(channel: 0, value: 0, universe: 1);
    return ArtnetState(
      ip: '',
      port: 0,
      brightness: DmxChannel.unused,
      torch: zero(),
      strobe: zero(),
      isBroadcasting: false,
      isReady: true,
    );
  }

  void packet({
    required int strobe,
    int torch = 255,
    int r = 255,
    int g = 0,
    int brightness = 255,
    List<RgbZone>? zones,
  }) {
    DmxChannel ch(int c, int v) =>
        DmxChannel(channel: c, value: v, universe: 1);
    state = state.copyWith(
      lastValidPacketTime: DateTime.now(),
      streamTerminated: false,
    );
    state = state.copyWith(
      zones: zones ?? [RgbZone(r, g, 0)],
      brightness: ch(4, brightness),
      torch: ch(5, torch),
      strobe: ch(6, strobe),
    );
  }

  void terminate() => state = state.copyWith(streamTerminated: true);
}

void main() {
  late List<String> torchCalls;
  late int brightnessCalls;

  setUp(() {
    torchCalls = [];
    brightnessCalls = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('github.com/aaassseee/screen_brightness'),
      (call) async {
        if (call.method == 'setApplicationScreenBrightness') {
          brightnessCalls++;
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.svprdga.torchlight/main'),
      (call) async {
        if (call.method == 'torch_available') return true;
        torchCalls.add(call.method);
        return null;
      },
    );
  });

  Future<FakeArtnet> showMode(
    WidgetTester tester,
    SignalLossAction action, {
    int fadeTimeMs = 0,
    int zoneCount = 1,
  }) async {
    final artnet = FakeArtnet();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStateProvider.overrideWith(
            () => FakeSettings(
              SettingsState(
                use4Channels: fadeTimeMs > 0,
                useTorchChannel: true,
                useStrobeChannel: true,
                signalLossAction: action,
                signalLossTimeout: 60,
                signalLossColor: 0x0000FF,
                fadeTimeMs: fadeTimeMs,
                zoneCount: zoneCount,
              ),
            ),
          ),
          artnetStateProvider.overrideWith(() => artnet),
        ],
        child: const MaterialApp(home: ShowPage()),
      ),
    );
    await tester.pump();
    return artnet;
  }

  // The colour actually drawn, so an animated blend would show up.
  Color screen(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(AnimatedContainer),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    return Color((box.decoration as BoxDecoration).color!.toARGB32());
  }

  List<Color> zones(WidgetTester tester) => [
    for (final box in tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(AnimatedContainer),
        matching: find.byType(DecoratedBox),
      ),
    ))
      Color((box.decoration as BoxDecoration).color!.toARGB32()),
  ];

  // Samples the screen every tick and returns how long each colour lasted.
  Future<List<(Color, Duration)>> watch(
    WidgetTester tester,
    Duration length,
  ) async {
    final runs = <(Color, Duration)>[];
    for (var t = Duration.zero; t < length; t += tick) {
      final color = screen(tester);
      if (runs.isNotEmpty && runs.last.$1 == color) {
        runs.last = (color, runs.last.$2 + tick);
      } else {
        runs.add((color, tick));
      }
      await tester.pump(tick);
    }
    return runs;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  for (final (action, lostLook) in [
    (SignalLossAction.blackout, black),
    (SignalLossAction.fade, black),
    (SignalLossAction.colour, const Color(0xFF0000FF)),
  ]) {
    testWidgets('${action.name} stops the strobe and the torch on loss', (
      tester,
    ) async {
      final artnet = await showMode(tester, action);
      artnet.packet(strobe: 255);
      await tester.pump();
      expect(
        (await watch(tester, const Duration(milliseconds: 600))).length,
        greaterThan(3),
      );

      artnet.terminate();
      await tester.pump(const Duration(seconds: 3));
      torchCalls.clear();
      final lost = await watch(tester, const Duration(seconds: 1));
      expect(lost, [(lostLook, const Duration(seconds: 1))]);
      expect(torchCalls, isEmpty);
      await close(tester);
    });
  }

  testWidgets('loss turns the torch off', (tester) async {
    final artnet = await showMode(tester, SignalLossAction.blackout);
    artnet.packet(strobe: 0);
    await tester.pump(halfPeriod);
    expect(torchCalls.last, 'enable_torch');

    artnet.terminate();
    await tester.pump(const Duration(seconds: 1));
    expect(torchCalls.last, 'disable_torch');
    await close(tester);
  });

  testWidgets('hold keeps the last colour without strobing', (tester) async {
    final artnet = await showMode(tester, SignalLossAction.hold);
    artnet.packet(strobe: 255);
    await tester.pump(halfPeriod + tick);
    expect(screen(tester), black);

    artnet.terminate();
    await tester.pump(halfPeriod);
    final held = await watch(tester, const Duration(seconds: 1));
    expect(held, [(red, const Duration(seconds: 1))]);
    await close(tester);
  });

  testWidgets('recovery restarts the strobe without a burst', (tester) async {
    final artnet = await showMode(tester, SignalLossAction.blackout);
    artnet.packet(strobe: 255);
    await tester.pump(halfPeriod * 3);
    artnet.terminate();
    await tester.pump(const Duration(seconds: 1));

    artnet.packet(strobe: 255);
    await tester.pump();
    final runs = await watch(tester, const Duration(seconds: 1));
    expect(runs.first.$1, red);
    // Sampling every tick can shorten a measured run by up to one tick.
    for (final (_, length) in runs.take(runs.length - 1)) {
      expect(length, greaterThanOrEqualTo(halfPeriod - tick));
    }
    expect(runs.where((run) => run.$1 == black).length, 3);
    await close(tester);
  });

  group('with a 2 s fade', () {
    testWidgets('strobe edges are hard cuts at 3 flashes a second', (
      tester,
    ) async {
      final artnet = await showMode(
        tester,
        SignalLossAction.blackout,
        fadeTimeMs: 2000,
      );
      artnet.packet(strobe: 0);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(screen(tester), red);
      final settled = brightnessCalls;

      artnet.packet(strobe: 255);
      final runs = await watch(tester, const Duration(seconds: 10));
      expect(runs.map((run) => run.$1).toSet(), {red, black});
      expect(runs.where((run) => run.$1 == black).length, 30);
      for (final (_, length) in runs.skip(1).take(runs.length - 2)) {
        expect(length, greaterThanOrEqualTo(halfPeriod - tick));
      }
      expect(brightnessCalls, settled);
      await close(tester);
    });

    testWidgets('a colour fade under the strobe never blends with black', (
      tester,
    ) async {
      final artnet = await showMode(
        tester,
        SignalLossAction.blackout,
        fadeTimeMs: 2000,
      );
      artnet.packet(strobe: 255);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      artnet.packet(strobe: 255, r: 0, g: 255);
      final runs = await watch(tester, const Duration(seconds: 3));
      for (final (color, _) in runs) {
        if (color == black) continue;
        final r = (color.r * 255).round();
        final g = (color.g * 255).round();
        expect(r + g, inInclusiveRange(254, 256));
      }
      expect(
        runs.skip(1).where((run) => run.$1 == black).length,
        lessThanOrEqualTo(9),
      );
      expect(
        runs.last.$1 == black || runs.last.$1 == const Color(0xFF00FF00),
        true,
      );
      await close(tester);
    });
  });
  group('with 4 zones', () {
    const look = [
      RgbZone(255, 0, 0),
      RgbZone(0, 255, 0),
      RgbZone(0, 0, 255),
      RgbZone(255, 255, 255),
    ];
    final lit = [for (final zone in look) zone.color];
    final dark = List.filled(4, black);

    testWidgets('the strobe cuts every zone together at 3 flashes a second', (
      tester,
    ) async {
      final artnet = await showMode(
        tester,
        SignalLossAction.blackout,
        fadeTimeMs: 2000,
        zoneCount: 4,
      );
      artnet.packet(strobe: 0, zones: look);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(zones(tester), lit);
      final settled = brightnessCalls;

      artnet.packet(strobe: 255, zones: look);
      final runs = <(List<Color>, Duration)>[];
      for (var t = Duration.zero; t < const Duration(seconds: 2); t += tick) {
        final now = zones(tester);
        if (runs.isNotEmpty && listEquals(runs.last.$1, now)) {
          runs.last = (now, runs.last.$2 + tick);
        } else {
          runs.add((now, tick));
        }
        await tester.pump(tick);
      }
      for (final (colors, _) in runs) {
        expect(colors, anyOf(equals(lit), equals(dark)));
      }
      expect(runs.where((run) => listEquals(run.$1, dark)).length, 6);
      for (final (_, length) in runs.skip(1).take(runs.length - 2)) {
        expect(length, greaterThanOrEqualTo(halfPeriod - tick));
      }
      expect(brightnessCalls, settled);
      await close(tester);
    });

    testWidgets('each zone fades on its own over the fade time', (
      tester,
    ) async {
      final artnet = await showMode(
        tester,
        SignalLossAction.blackout,
        fadeTimeMs: 1000,
        zoneCount: 4,
      );
      artnet.packet(strobe: 0, zones: look);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      final swapped = look.reversed.toList();
      artnet.packet(strobe: 0, zones: swapped);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final mid = zones(tester);
      expect(mid[0].r, closeTo(1, 0.01));
      expect(mid[0].g, closeTo(0.5, 0.01));
      expect(mid[0].b, closeTo(0.5, 0.01));
      expect(mid[1].r, closeTo(0, 0.01));
      expect(mid[1].g, closeTo(0.5, 0.01));
      expect(mid[1].b, closeTo(0.5, 0.01));

      await tester.pump(const Duration(milliseconds: 600));
      expect(zones(tester), [for (final zone in swapped) zone.color]);
      await close(tester);
    });

    testWidgets('without a fade every zone changes at once', (tester) async {
      final artnet = await showMode(
        tester,
        SignalLossAction.blackout,
        zoneCount: 4,
      );
      artnet.packet(strobe: 0, zones: look);
      await tester.pump();
      expect(zones(tester), lit);
      final settled = brightnessCalls;

      artnet.packet(strobe: 0, zones: look.reversed.toList());
      await tester.pump();
      expect(zones(tester), lit.reversed.toList());
      expect(brightnessCalls, settled);
      await close(tester);
    });

    for (final (action, lostLook) in [
      (SignalLossAction.blackout, black),
      (SignalLossAction.colour, const Color(0xFF0000FF)),
    ]) {
      testWidgets('${action.name} covers every zone on loss', (tester) async {
        final artnet = await showMode(tester, action, zoneCount: 4);
        artnet.packet(strobe: 0, zones: look);
        await tester.pump();
        expect(zones(tester), lit);

        artnet.terminate();
        await tester.pump(const Duration(seconds: 1));
        expect(zones(tester), List.filled(4, lostLook));
        await close(tester);
      });
    }

    testWidgets('hold keeps every zone and stops the strobe', (tester) async {
      final artnet = await showMode(
        tester,
        SignalLossAction.hold,
        zoneCount: 4,
      );
      artnet.packet(strobe: 255, zones: look);
      await tester.pump(halfPeriod + tick);
      expect(zones(tester), dark);

      artnet.terminate();
      await tester.pump(halfPeriod);
      for (var t = Duration.zero; t < const Duration(seconds: 1); t += tick) {
        expect(zones(tester), lit);
        await tester.pump(tick);
      }
      await close(tester);
    });

    testWidgets('recovery snaps every zone even with a fade', (tester) async {
      final artnet = await showMode(
        tester,
        SignalLossAction.blackout,
        fadeTimeMs: 2000,
        zoneCount: 4,
      );
      artnet.packet(strobe: 0, zones: look);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      artnet.terminate();
      await tester.pump(const Duration(seconds: 1));
      expect(zones(tester), dark);

      artnet.packet(strobe: 0, zones: look.reversed.toList());
      await tester.pump();
      expect(zones(tester), lit.reversed.toList());
      await close(tester);
    });
  });
}
