import 'dart:convert';

import 'package:chromapulse/dimmer.dart';
import 'package:chromapulse/providers/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingsState', () {
    test('channelCount covers RGB, brightness and torch', () {
      expect(SettingsState(use4Channels: false).channelCount, 3);
      expect(SettingsState(use4Channels: true).channelCount, 4);
      expect(
        SettingsState(use4Channels: false, useTorchChannel: true).channelCount,
        4,
      );
      expect(
        SettingsState(use4Channels: true, useTorchChannel: true).channelCount,
        5,
      );
    });

    test('torch channel follows brightness when enabled', () {
      expect(SettingsState(use4Channels: true).torchChannelOffset, 4);
      expect(SettingsState(use4Channels: false).torchChannelOffset, 3);
    });

    test('fitsUniverse checks the whole channel range', () {
      expect(SettingsState(dmxStartChannel: 509).fitsUniverse, true);
      expect(
        SettingsState(dmxStartChannel: 509, useTorchChannel: true).fitsUniverse,
        false,
      );
      expect(SettingsState(dmxStartChannel: 0).fitsUniverse, false);
      expect(SettingsState(dmxStartChannel: -5).fitsUniverse, false);
    });

    test('copyWith keeps unrelated fields', () {
      final settings = SettingsState(
        use4Channels: false,
        useTorchChannel: true,
      );
      final updated = settings.copyWith(controllerPort: 1234);
      expect(updated.use4Channels, false);
      expect(updated.useTorchChannel, true);
      expect(updated.controllerPort, 1234);
    });

    test('JSON round trip', () {
      final settings = SettingsState(
        dmxStartChannel: 10,
        universe: 2,
        controllerIpAddress: '10.0.0.1',
        use4Channels: false,
        useTorchChannel: true,
        deviceName: 'Stage Left 3',
        dimmerCurve: DimmerCurve.square,
        curveRgb: true,
        fadeTimeMs: 250,
      );
      final decoded = SettingsState.fromJson(settings.toJson());
      expect(decoded, settings);
      expect(decoded.deviceName, 'Stage Left 3');
    });

    test('device name defaults to ChromaPulse', () {
      expect(SettingsState().deviceName, 'ChromaPulse');
    });

    test('configs exported before the device name still import', () {
      final settings = SettingsState.fromJson(
        '{"dmxStartChannel":5,"universe":1,"allowBroadcast":true,'
        '"controllerIpAddress":"","controllerPort":6454,"use4Channels":true,'
        '"useTorchChannel":false}',
      );
      expect(settings.deviceName, 'ChromaPulse');
      expect(settings.dmxStartChannel, 5);
    });

    test('export JSON omits the per-device name', () {
      final settings = SettingsState(
        dmxStartChannel: 7,
        protocol: DmxProtocol.sacn,
        deviceName: 'Bar',
      );
      final exported = settings.toSharedJson();
      expect(json.decode(exported), isNot(contains('deviceName')));
      final imported = SettingsState.fromJson(exported);
      expect(imported.deviceName, 'ChromaPulse');
      expect(imported.dmxStartChannel, 7);
      expect(imported.protocol, DmxProtocol.sacn);
    });

    test('parseDeviceName accepts trimmed printable ASCII up to 17 chars', () {
      expect(SettingsState.parseDeviceName('Stage Left 3'), 'Stage Left 3');
      expect(SettingsState.parseDeviceName('  Bar  '), 'Bar');
      expect(
        SettingsState.parseDeviceName('12345678901234567'),
        '12345678901234567',
      );
    });

    test('parseDeviceName rejects empty, long and non-ASCII names', () {
      expect(SettingsState.parseDeviceName(''), isNull);
      expect(SettingsState.parseDeviceName('   '), isNull);
      expect(SettingsState.parseDeviceName('123456789012345678'), isNull);
      expect(SettingsState.parseDeviceName('Café'), isNull);
      expect(SettingsState.parseDeviceName('Lamp 🔦'), isNull);
    });

    test('configs exported before the torch channel still import', () {
      final settings = SettingsState.fromJson(
        '{"dmxStartChannel":5,"universe":1,"allowBroadcast":true,'
        '"controllerIpAddress":"","controllerPort":6454,"use4Channels":true}',
      );
      expect(settings.useTorchChannel, false);
      expect(settings.dmxStartChannel, 5);
    });

    test('configs exported before the protocol setting import as Art-Net', () {
      final settings = SettingsState.fromJson(
        '{"dmxStartChannel":5,"universe":1,"allowBroadcast":true,'
        '"controllerIpAddress":"","controllerPort":6454,"use4Channels":true,'
        '"useTorchChannel":true}',
      );
      expect(settings.protocol, DmxProtocol.artnet);
      expect(settings.useTorchChannel, true);
    });

    test('protocol survives the JSON round trip', () {
      final settings = SettingsState(protocol: DmxProtocol.sacn);
      expect(
        SettingsState.fromJson(settings.toJson()).protocol,
        DmxProtocol.sacn,
      );
    });

    test('signal loss defaults to holding the last look', () {
      final settings = SettingsState();
      expect(settings.signalLossAction, SignalLossAction.hold);
      expect(settings.signalLossTimeout, 4);
      expect(settings.signalLossColor, 0xFFFFFF);
    });

    test('configs exported before signal loss still import', () {
      final settings = SettingsState.fromJson(
        '{"dmxStartChannel":5,"universe":1,"allowBroadcast":true,'
        '"controllerIpAddress":"","controllerPort":6454,"use4Channels":true,'
        '"useTorchChannel":true}',
      );
      expect(settings.signalLossAction, SignalLossAction.hold);
      expect(settings.signalLossTimeout, 4);
      expect(settings.signalLossColor, 0xFFFFFF);
      expect(settings.useTorchChannel, true);
    });

    test('signal loss settings survive a JSON round trip', () {
      final settings = SettingsState(
        signalLossAction: SignalLossAction.fade,
        signalLossTimeout: 7,
        signalLossColor: 0x00FF00,
      );
      final restored = SettingsState.fromJson(settings.toJson());
      expect(restored, settings);
      expect(restored.signalLossAction, SignalLossAction.fade);
      expect(restored.signalLossTimeout, 7);
      expect(restored.signalLossColor, 0x00FF00);
    });

    test('the shared config carries the signal loss settings', () {
      final settings = SettingsState(
        deviceName: 'Bar',
        signalLossAction: SignalLossAction.colour,
        signalLossTimeout: 9,
        signalLossColor: 0xFF8800,
      );
      final imported = SettingsState.fromJson(settings.toSharedJson());
      expect(imported.deviceName, 'ChromaPulse');
      expect(imported.signalLossAction, SignalLossAction.colour);
      expect(imported.signalLossTimeout, 9);
      expect(imported.signalLossColor, 0xFF8800);
    });

    test('unknown signal loss action falls back to hold', () {
      final settings = SettingsState.fromJson('{"signalLossAction":"explode"}');
      expect(settings.signalLossAction, SignalLossAction.hold);
    });

    test('imported signal loss values are kept in range', () {
      final settings = SettingsState.fromJson(
        '{"signalLossTimeout":0,"signalLossColor":4294967295}',
      );
      expect(settings.signalLossTimeout, 1);
      expect(settings.signalLossColor, 0xFFFFFF);
    });

    test('isSignalLost compares the last packet against the timeout', () {
      final settings = SettingsState(signalLossTimeout: 4);
      final now = DateTime(2025, 1, 1, 12);
      expect(settings.isSignalLost(null, now), true);
      expect(
        settings.isSignalLost(now.subtract(const Duration(seconds: 3)), now),
        false,
      );
      expect(
        settings.isSignalLost(now.subtract(const Duration(seconds: 4)), now),
        true,
      );
    });

    test('configs exported before dimmer curves still import', () {
      final settings = SettingsState.fromJson(
        '{"dmxStartChannel":5,"universe":1,"allowBroadcast":true,'
        '"controllerIpAddress":"","controllerPort":6454,"use4Channels":true,'
        '"useTorchChannel":true}',
      );
      expect(settings.dimmerCurve, DimmerCurve.linear);
      expect(settings.curveRgb, false);
      expect(settings.fadeTimeMs, 0);
      expect(settings.useTorchChannel, true);
    });

    test('export JSON shares the curve and fade settings', () {
      final settings = SettingsState(
        dimmerCurve: DimmerCurve.square,
        curveRgb: true,
        fadeTimeMs: 400,
      );
      final imported = SettingsState.fromJson(settings.toSharedJson());
      expect(imported.dimmerCurve, DimmerCurve.square);
      expect(imported.curveRgb, true);
      expect(imported.fadeTimeMs, 400);
    });

    test('imported fade times are clamped', () {
      expect(SettingsState.fromMap({'fadeTimeMs': -500}).fadeTimeMs, 0);
      expect(SettingsState.fromMap({'fadeTimeMs': 1e12}).fadeTimeMs, 10000);
    });

    test('an unknown dimmer curve falls back to linear', () {
      expect(
        SettingsState.fromMap({'dimmerCurve': 'cubic'}).dimmerCurve,
        DimmerCurve.linear,
      );
    });
  });
}
