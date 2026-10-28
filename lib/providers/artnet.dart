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

  static final unused = DmxChannel(channel: -1, value: -1, universe: -1);
}

class ArtnetState {
  final String ip;
  final int port;
  final DmxChannel red;
  final DmxChannel green;
  final DmxChannel blue;
  final DmxChannel brightness;
  final DmxChannel torch;
  final bool isBroadcasting;
  final bool isReady;
  final DateTime? lastValidPacketTime;

  ArtnetState({
    required this.ip,
    required this.port,
    required this.red,
    required this.green,
    required this.blue,
    required this.brightness,
    required this.torch,
    required this.isBroadcasting,
    this.lastValidPacketTime,
    this.isReady = false,
  });

  ArtnetState copyWith({
    String? ip,
    int? port,
    DmxChannel? red,
    DmxChannel? green,
    DmxChannel? blue,
    DmxChannel? brightness,
    DmxChannel? torch,
    bool? isBroadcasting,
    bool? isReady,
    DateTime? lastValidPacketTime,
  }) {
    return ArtnetState(
      ip: ip ?? this.ip,
      port: port ?? this.port,
      red: red ?? this.red,
      green: green ?? this.green,
      blue: blue ?? this.blue,
      brightness: brightness ?? this.brightness,
      torch: torch ?? this.torch,
      isBroadcasting: isBroadcasting ?? this.isBroadcasting,
      isReady: isReady ?? this.isReady,
      lastValidPacketTime: lastValidPacketTime ?? this.lastValidPacketTime,
    );
  }
}

class ArtnetProvider extends Notifier<ArtnetState> {
  RawDatagramSocket? _udp;

  @override
  ArtnetState build() {
    // Rebind the socket whenever the port changes. Watching also keeps the
    // settings provider alive while we read it for every packet.
    final port = ref.watch(
      settingsStateProvider.select((s) => s.controllerPort),
    );
    ref.onDispose(() => _udp?.close());
    _init(port);

    return ArtnetState(
      ip: '',
      port: 0,
      red: DmxChannel(channel: 0, value: 0, universe: 0),
      green: DmxChannel(channel: 0, value: 0, universe: 0),
      blue: DmxChannel(channel: 0, value: 0, universe: 0),
      brightness: DmxChannel(channel: 0, value: 255, universe: 0),
      torch: DmxChannel(channel: 0, value: 0, universe: 0),
      isBroadcasting: false,
    );
  }

  Future<void> _init(int port) async {
    final settings = ref.read(settingsStateProvider);

    // Subscribe to UDP packets
    final RawDatagramSocket udp;
    try {
      udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
    } catch (e) {
      return;
    }
    if (!ref.mounted) {
      udp.close();
      return;
    }
    _udp = udp;

    udp.listen((event) {
      if (event == RawSocketEvent.read) {
        final packet = udp.receive();
        if (packet != null) handleData(packet);
      }
    });

    state = state.copyWith(
      ip: settings.controllerIpAddress,
      port: port,
      isReady: true,
    );
  }

  void setBroadcasting(bool value) {
    state = state.copyWith(isBroadcasting: value, isReady: true);
  }

  void handleData(Datagram data) {
    // ArtnetCheckPacket reads the 8-byte ID and the opcode without bounds checks
    if (data.data.length < 10 || !ArtnetCheckPacket(data.data)) return;

    final settings = ref.read(settingsStateProvider);
    state = state.copyWith(isReady: true, lastValidPacketTime: DateTime.now());

    // Parse the packet
    final opCode = ArtnetGetOpCode(data.data);
    if (opCode == ArtnetPollPacket.opCode) {
      sendArtPollReply();
    } else if (opCode == ArtnetDataPacket.opCode) {
      final dmx = ArtnetDataPacket(packet: data.data);

      if (dmx.universe != settings.universe - 1) {
        return;
      }

      // Art-Net allows short frames, treat missing channels as 0
      DmxChannel channel(int offset) {
        final index = settings.dmxStartChannel - 1 + offset;
        return DmxChannel(
          channel: settings.dmxStartChannel + offset,
          value: index >= 0 && index < dmx.dmx.length ? dmx.dmx[index] : 0,
          universe: settings.universe,
        );
      }

      state = state.copyWith(
        red: channel(0),
        green: channel(1),
        blue: channel(2),
        brightness: settings.use4Channels ? channel(3) : DmxChannel.unused,
        torch: settings.useTorchChannel
            ? channel(settings.torchChannelOffset)
            : DmxChannel.unused,
      );
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
        ref.read(settingsStateProvider).dmxStartChannel + 3,
        0,
      );
    }

    packet.setPortTypesInputArtnetAble(
      ref.read(settingsStateProvider).dmxStartChannel,
      true,
    );
    packet.setPortTypesOutputArtnetAble(
      ref.read(settingsStateProvider).dmxStartChannel + 1,
      true,
    );
    packet.setPortTypesOutputArtnetAble(
      ref.read(settingsStateProvider).dmxStartChannel + 2,
      true,
    );
    if (ref.read(settingsStateProvider).use4Channels) {
      packet.setPortTypesOutputArtnetAble(
        ref.read(settingsStateProvider).dmxStartChannel + 3,
        true,
      );
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
