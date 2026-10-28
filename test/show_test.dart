import 'package:chromapulse/providers/artnet.dart';
import 'package:chromapulse/providers/providers.dart';
import 'package:chromapulse/providers/settings.dart';
import 'package:chromapulse/show.dart';
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
      red: zero(),
      green: zero(),
      blue: zero(),
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
  }) {
    DmxChannel ch(int c, int v) =>
        DmxChannel(channel: c, value: v, universe: 1);
    state = state.copyWith(
      lastValidPacketTime: DateTime.now(),
      streamTerminated: false,
    );
    state = state.copyWith(
      red: ch(1, r),
      green: ch(2, g),
      blue: ch(3, 0),
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
}
