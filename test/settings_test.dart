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
      );
      expect(SettingsState.fromJson(settings.toJson()), settings);
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
  });
}
