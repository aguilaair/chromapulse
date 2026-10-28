import 'package:chromapulse/dimmer.dart';
import 'package:chromapulse/providers/artnet.dart';
import 'package:chromapulse/providers/providers.dart';
import 'package:chromapulse/providers/settings.dart';
import 'package:chromapulse/show.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class FakeSettings extends SettingsProvider {
  FakeSettings(this.settings);

  final SettingsState settings;

  @override
  SettingsState build() => settings;
}

class FakeArtnet extends ArtnetProvider {
  @override
  ArtnetState build() => ArtnetState(
    ip: '',
    port: 0,
    red: _channel(0),
    green: _channel(0),
    blue: _channel(0),
    brightness: _channel(255),
    torch: DmxChannel.unused,
    isBroadcasting: false,
    isReady: true,
  );

  static DmxChannel _channel(int value) =>
      DmxChannel(channel: 1, value: value, universe: 1);

  /// Mirrors ArtnetProvider.handleData: timestamp first, then channel values.
  void packet(int r, int g, int b) {
    state = state.copyWith(lastValidPacketTime: DateTime.now());
    state = state.copyWith(
      red: _channel(r),
      green: _channel(g),
      blue: _channel(b),
    );
  }

  void goSilent() {
    state = state.copyWith(
      lastValidPacketTime: DateTime.now().subtract(const Duration(minutes: 1)),
    );
  }
}

Color shownColour(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(AnimatedContainer),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).color!;
}

Future<FakeArtnet> pumpShow(
  WidgetTester tester,
  SignalLossAction action, {
  bool curveRgb = false,
}) async {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('github.com/aaassseee/screen_brightness'),
    (_) async => null,
  );
  messenger.setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
  );
  final artnet = FakeArtnet();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsStateProvider.overrideWith(
          () => FakeSettings(
            SettingsState(
              fadeTimeMs: 5000,
              dimmerCurve: DimmerCurve.square,
              curveRgb: curveRgb,
              signalLossAction: action,
              signalLossColor: 0x808080,
              signalLossTimeout: 1,
            ),
          ),
        ),
        artnetStateProvider.overrideWith(() => artnet),
      ],
      child: const MaterialApp(home: ShowPage()),
    ),
  );
  artnet.packet(255, 0, 0);
  await tester.pump();
  await tester.pump(const Duration(seconds: 6));
  expect(shownColour(tester), const Color(0xFFFF0000));
  artnet.packet(0, 0, 255);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return artnet;
}

void main() {
  testWidgets('blackout replaces a running fade at once', (tester) async {
    final artnet = await pumpShow(tester, SignalLossAction.blackout);
    expect(shownColour(tester), isNot(const Color(0xFF0000FF)));

    artnet.goSilent();
    await tester.pump();
    await tester.pump();
    expect(shownColour(tester), Colors.black);
  });

  testWidgets('signal loss fade keeps its own 2 s duration', (tester) async {
    final artnet = await pumpShow(tester, SignalLossAction.fade);

    artnet.goSilent();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(shownColour(tester), isNot(Colors.black));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(shownColour(tester), Colors.black);
  });

  testWidgets('recovery shows the new packet without fading', (tester) async {
    final artnet = await pumpShow(tester, SignalLossAction.blackout);
    artnet.goSilent();
    await tester.pump();

    artnet.packet(0, 255, 0);
    await tester.pump();
    expect(shownColour(tester), const Color(0xFF00FF00));
  });

  testWidgets('the signal loss colour skips the dimmer curve', (tester) async {
    final artnet = await pumpShow(
      tester,
      SignalLossAction.colour,
      curveRgb: true,
    );
    artnet.goSilent();
    await tester.pump();
    await tester.pump();
    expect(shownColour(tester), const Color(0xFF808080));
  });
}
