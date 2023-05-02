import 'dart:async';
import 'dart:io';

import 'package:chromapulse/providers/providers.dart';
import 'package:d_artnet_4/d_artnet_4.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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

  RawDatagramSocket? _udp;

  @override
  void dispose() {
    _udp?.close();
    if (mounted) super.dispose();
  }

  Future<void> _init() async {
    final settings = ref.read(settingsStateProvider);

    // Subscribe to UDP packets
    try {
      _udp = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        settings.controllerPort,
      );
    } catch (e) {
      return;
    }

    _udp?.listen((event) {
      if (event == RawSocketEvent.read) {
        final packet = _udp!.receive();
        handleData(packet);
      }
    });

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
    final settings = ref.read(settingsStateProvider);
    final isValid = ArtnetCheckPacket(data!.data);

    if (isValid) {
      // Parse the packet
      final opCode = ArtnetGetOpCode(data.data);
      if (opCode == ArtnetPollPacket.opCode) {
        sendArtPollReply();
      } else if (opCode == ArtnetDataPacket.opCode) {
        final dmx = ArtnetDataPacket(packet: data.data);

        if (dmx.universe != settings.universe - 1) {
          return;
        }

        // Get the channels we need
        final dmxToWatch = dmx.dmx.sublist(settings.dmxStartChannel - 1,
            settings.dmxStartChannel - 1 + (settings.use4Channels ? 4 : 3));

        state = state = ArtnetState(
          ip: state.ip,
          port: state.port,
          red: DmxChannel(
            channel: settings.dmxStartChannel,
            value: dmxToWatch[0],
            universe: settings.universe,
          ),
          green: DmxChannel(
            channel: settings.dmxStartChannel,
            value: dmxToWatch[1],
            universe: settings.universe,
          ),
          blue: DmxChannel(
            channel: settings.dmxStartChannel,
            value: dmxToWatch[2],
            universe: settings.universe,
          ),
          brightness: settings.use4Channels
              ? DmxChannel(
                  channel: settings.dmxStartChannel,
                  value: dmxToWatch[3],
                  universe: settings.universe,
                )
              : DmxChannel(
                  channel: -1,
                  value: -1,
                  universe: -1,
                ),
          isBroadcasting: state.isBroadcasting,
          isReady: true,
        );
      }
    }
  }

  void sendArtPollReply() {
    final settings = ref.read(settingsStateProvider);
    final ip = ref
        .read(networkStateProvider)
        .ipAddress!
        .split('.')
        .map((e) => int.parse(e))
        .toList();
    final packet = ArtnetPollReplyPacket();
    packet.ip = ip;
    packet.port = ref.read(settingsStateProvider).controllerPort;
    packet.shortName = 'ChromaPulse v1.0.0';
    packet.longName = 'ChromaPulse';
    packet.universe = ref.read(settingsStateProvider).universe;
    packet.status2IpIsSetManually = true;
    packet.setPortType(ref.read(settingsStateProvider).dmxStartChannel, 0);
    packet.setPortType(ref.read(settingsStateProvider).dmxStartChannel + 1, 0);
    packet.setPortType(ref.read(settingsStateProvider).dmxStartChannel + 2, 0);
    if (ref.read(settingsStateProvider).use4Channels) {
      packet.setPortType(
          ref.read(settingsStateProvider).dmxStartChannel + 3, 0);
    }

    packet.setPortTypesInputArtnetAble(
        ref.read(settingsStateProvider).dmxStartChannel, true);
    packet.setPortTypesOutputArtnetAble(
        ref.read(settingsStateProvider).dmxStartChannel + 1, true);
    packet.setPortTypesOutputArtnetAble(
        ref.read(settingsStateProvider).dmxStartChannel + 2, true);
    if (ref.read(settingsStateProvider).use4Channels) {
      packet.setPortTypesOutputArtnetAble(
          ref.read(settingsStateProvider).dmxStartChannel + 3, true);
    }

    packet.setSwOut(ref.read(settingsStateProvider).dmxStartChannel, 0);
    packet.setSwOut(ref.read(settingsStateProvider).dmxStartChannel + 1, 0);
    packet.setSwOut(ref.read(settingsStateProvider).dmxStartChannel + 2, 0);
    if (ref.read(settingsStateProvider).use4Channels) {
      packet.setSwOut(ref.read(settingsStateProvider).dmxStartChannel + 3, 0);
    }
    _udp?.broadcastEnabled = true;
    _udp?.send(
      packet.udpPacket,
      InternetAddress(settings.controllerIpAddress),
      settings.controllerPort,
    );
  }
}
