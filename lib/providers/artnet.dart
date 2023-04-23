import 'dart:async';
import 'dart:io';

import 'package:chromapulse/providers/providers.dart';
import 'package:d_artnet_4/d_artnet_4.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:udp/udp.dart';

class DmxChannel {
  final int channel;
  final int value;
  final int universe;

  DmxChannel({
    required this.channel,
    required this.value,
    required this.universe,
  });
}

class ArtnetState {
  final String ip;
  final int port;
  final DmxChannel red;
  final DmxChannel green;
  final DmxChannel blue;
  final DmxChannel brightness;
  final bool isBroadcasting;
  final bool isReady;

  ArtnetState({
    required this.ip,
    required this.port,
    required this.red,
    required this.green,
    required this.blue,
    required this.brightness,
    required this.isBroadcasting,
    this.isReady = false,
  });
}

class ArtnetProvider extends StateNotifier<ArtnetState> {
  final Ref ref;

  ArtnetProvider(this.ref)
      : super(ArtnetState(
          ip: '',
          port: 0,
          red: DmxChannel(channel: 0, value: 0, universe: 0),
          green: DmxChannel(channel: 0, value: 0, universe: 0),
          blue: DmxChannel(channel: 0, value: 0, universe: 0),
          brightness: DmxChannel(channel: 0, value: 0, universe: 0),
          isBroadcasting: false,
        )) {
    _init();
  }

  UDP? _udp;
  Timer? _timer;

  Future<void> _init() async {
    final settings = ref.read(settingsStateProvider);
    final network = ref.read(networkStateProvider);

    // Subscribe to UDP packets
    try {
      _udp = await UDP.bind(Endpoint.unicast(
        InternetAddress(settings.controllerIpAddress),
        port: Port(settings.controllerPort),
      ));
    } catch (e) {
      return;
    }

    _udp?.asStream().listen(handleData);

    state = ArtnetState(
      ip: settings.controllerIpAddress,
      port: settings.controllerPort,
      red: DmxChannel(channel: 0, value: 0, universe: 0),
      green: DmxChannel(channel: 0, value: 0, universe: 0),
      blue: DmxChannel(channel: 0, value: 0, universe: 0),
      brightness: DmxChannel(channel: 0, value: 0, universe: 0),
      isBroadcasting: state.isBroadcasting,
      isReady: true,
    );
  }

  void setBroadcasting(bool value) {
    state = ArtnetState(
      ip: state.ip,
      port: state.port,
      red: state.red,
      green: state.green,
      blue: state.blue,
      brightness: state.brightness,
      isBroadcasting: value,
      isReady: true,
    );
  }

  void handleData(Datagram? data) {
    print(data);
    final isValid = ArtnetCheckPacket(data!.data);

    if (isValid) {
      print('Valid Artnet Packet');
      // Parse the packet
      final opCode = ArtnetGetOpCode(data.data);
      if (opCode == ArtnetPollPacket.opCode) {
        print('OpPoll');
        final ip = ref
            .read(networkStateProvider)
            .ipAddress!
            .split('.')
            .map((e) => int.parse(e))
            .toList();
        final packet = ArtnetPollReplyPacket(packet: [
          ...ArtnetPollReplyPacket.love,
          ...ArtnetPollReplyPacket.pride,
          ArtnetPollReplyPacket.opCode,
          ip[0],
          ip[1],
          ip[2],
          ip[3],
          0x1936,
          0x00,
          0x00,
          0x00,
          0x00,
          ArtnetPollReplyPacket.netSwitchMask,
          ArtnetPollReplyPacket.subSwitchMask,
          0x00,
          0x00,
          0x00,
          0xE0,
          0x00,
          0x00,
          ..."ChromaPulse 1.0.0".codeUnits,
          // Null terminate the string
          0x00,
          ..."ChromaPulse 1.0.0 by Eduardo Moreno Adanez for Stanford TAPS 23"
              .codeUnits,
          0x00,
        ]);
        _udp?.send(
            packet.udpPacket,
            Endpoint.unicast(
              InternetAddress(state.ip),
              port: Port(state.port),
            ));
      }
    }
  }
}
