import 'dart:io';

import 'package:chromapulse/providers/providers.dart';
import 'package:chromapulse/providers/sacn.dart';
import 'package:chromapulse/providers/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'sacn_test.dart' show e131;

Future<ProviderContainer> receiver(DmxProtocol protocol) async {
  final box = await Hive.openBox(SettingsProvider.key);
  await box.put(
    SettingsProvider.key,
    SettingsState(protocol: protocol, universe: 2).toJson(),
  );
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.listen(artnetStateProvider, (_, _) {});
  await Future.delayed(const Duration(milliseconds: 200));
  return container;
}

Future<void> send(InternetAddress host, List<int> packet) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  socket.send(packet, host, sacnPort);
  socket.close();
  await Future.delayed(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(() async {
    Hive.init((await Directory.systemTemp.createTemp('chromapulse')).path);
  });

  test('sACN mode applies unicast packets for its universe', () async {
    final container = await receiver(DmxProtocol.sacn);
    await send(InternetAddress.loopbackIPv4, e131(universe: 2));
    await send(InternetAddress.loopbackIPv4, e131(universe: 1, dmx: [9, 9, 9]));
    final state = container.read(artnetStateProvider);
    expect(
      [state.red.value, state.green.value, state.blue.value],
      [255, 128, 0],
    );
  });

  test('Art-Net mode ignores sACN', () async {
    final container = await receiver(DmxProtocol.artnet);
    await send(InternetAddress.loopbackIPv4, e131(universe: 2));
    expect(container.read(artnetStateProvider).lastValidPacketTime, null);
  });
}
