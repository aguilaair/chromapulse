import 'dart:io';

import 'package:chromapulse/molecules/config/device.dart';
import 'package:chromapulse/providers/providers.dart';
import 'package:chromapulse/providers/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('chromapulse_test');
    Hive.init(dir.path);
    final box = await Hive.openBox(SettingsProvider.key);
    await box.put(
      SettingsProvider.key,
      SettingsState(dmxStartChannel: 509).toJson(),
    );
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  testWidgets('torch channel cannot push the patch past channel 512', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DeviceConfigurationTile()),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Device Configuration'));
    await tester.pumpAndSettle();

    final torchSwitch = find.descendant(
      of: find.widgetWithText(ListTile, 'Torch Channel'),
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(torchSwitch);
    await tester.tap(torchSwitch);
    await tester.pump();

    expect(find.textContaining('Not enough channels left'), findsOneWidget);
    expect(container.read(settingsStateProvider).useTorchChannel, false);
    expect(find.text('509 through 512'), findsOneWidget);
  });

  testWidgets('strobe channel cannot push the patch past channel 512', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DeviceConfigurationTile()),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Device Configuration'));
    await tester.pumpAndSettle();

    final strobeSwitch = find.descendant(
      of: find.widgetWithText(ListTile, 'Strobe Channel'),
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(strobeSwitch);
    await tester.tap(strobeSwitch);
    await tester.pump();

    expect(find.textContaining('Not enough channels left'), findsOneWidget);
    expect(container.read(settingsStateProvider).useStrobeChannel, false);
    expect(find.text('509 through 512'), findsOneWidget);
  });

  testWidgets('extra zones cannot push the patch past channel 512', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DeviceConfigurationTile()),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Device Configuration'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Not enough channels left'), findsOneWidget);
    expect(container.read(settingsStateProvider).zoneCount, 1);
    expect(find.text('509 through 512'), findsOneWidget);
  });

  testWidgets('zone count widens the DMX channel range', (tester) async {
    final container = ProviderContainer(
      overrides: [settingsStateProvider.overrideWith(_InMemorySettings.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ListView(children: const [DeviceConfigurationTile()]),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Device Configuration'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4').last);
    await tester.pumpAndSettle();

    expect(container.read(settingsStateProvider).zoneCount, 4);
    expect(find.text('1 through 13'), findsOneWidget);
    expect(find.text('Zone Layout'), findsOneWidget);
  });
}

// Hive writes never complete inside the widget test's fake async zone
class _InMemorySettings extends SettingsProvider {
  @override
  SettingsState build() => SettingsState();

  @override
  void saveSettings() {}
}
