import 'dart:async';
import 'dart:io';

import 'package:chromapulse/providers/providers.dart';
import 'package:chromapulse/providers/sacn.dart';
import 'package:chromapulse/providers/settings.dart';
import 'package:d_artnet_4/d_artnet_4.dart';
import 'package:flutter/services.dart';
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
  final DmxChannel strobe;
  final bool isBroadcasting;
  final bool isReady;
  final DateTime? lastValidPacketTime;
  final bool streamTerminated;

  ArtnetState({
    required this.ip,
    required this.port,
    required this.red,
    required this.green,
    required this.blue,
    required this.brightness,
    required this.torch,
    DmxChannel? strobe,
    required this.isBroadcasting,
    this.lastValidPacketTime,
    this.isReady = false,
    this.streamTerminated = false,
  }) : strobe = strobe ?? DmxChannel.unused;

  ArtnetState copyWith({
    String? ip,
    int? port,
    DmxChannel? red,
    DmxChannel? green,
    DmxChannel? blue,
    DmxChannel? brightness,
    DmxChannel? torch,
    DmxChannel? strobe,
    bool? isBroadcasting,
    bool? isReady,
    DateTime? lastValidPacketTime,
    bool? streamTerminated,
  }) {
    return ArtnetState(
      ip: ip ?? this.ip,
      port: port ?? this.port,
      red: red ?? this.red,
      green: green ?? this.green,
      blue: blue ?? this.blue,
      brightness: brightness ?? this.brightness,
      torch: torch ?? this.torch,
      strobe: strobe ?? this.strobe,
      isBroadcasting: isBroadcasting ?? this.isBroadcasting,
      isReady: isReady ?? this.isReady,
      lastValidPacketTime: lastValidPacketTime ?? this.lastValidPacketTime,
      streamTerminated: streamTerminated ?? this.streamTerminated,
    );
  }
}

class ArtnetProvider extends Notifier<ArtnetState> {
  static const _multicastChannel = MethodChannel(
    'dev.eduardom.chromapulse/multicast',
  );

  RawDatagramSocket? _udp;
  RawDatagramSocket? _sacnUdp;
  var _sacnArbiter = SacnSourceArbiter();

  // Bumped on dispose so binds still in flight from an earlier build bail out
  var _generation = 0;

  @override
  ArtnetState build() {
    // Rebind the sockets whenever these change. Watching also keeps the
    // settings provider alive while we read it for every packet.
    final (port, protocol, universe) = ref.watch(
      settingsStateProvider.select(
        (s) => (s.controllerPort, s.protocol, s.universe),
      ),
    );
    ref.onDispose(() {
      _generation++;
      _udp?.close();
      _sacnUdp?.close();
      _udp = _sacnUdp = null;
      if (protocol.receivesSacn) _setMulticastLock(false);
    });
    _sacnArbiter = SacnSourceArbiter();
    if (protocol.receivesArtnet) _bindArtnet(port);
    if (protocol.receivesSacn) _bindSacn(universe);

    return ArtnetState(
      ip: '',
      port: 0,
      red: DmxChannel(channel: 0, value: 0, universe: 0),
      green: DmxChannel(channel: 0, value: 0, universe: 0),
      blue: DmxChannel(channel: 0, value: 0, universe: 0),
      brightness: DmxChannel(channel: 0, value: 255, universe: 0),
      torch: DmxChannel(channel: 0, value: 0, universe: 0),
      strobe: DmxChannel(channel: 0, value: 0, universe: 0),
      isBroadcasting: false,
    );
  }

  Future<RawDatagramSocket?> _bind(
    int port,
    int generation,
    void Function(Datagram) onPacket,
  ) async {
    final RawDatagramSocket udp;
    try {
      udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
    } catch (e) {
      return null;
    }
    if (generation != _generation) {
      udp.close();
      return null;
    }

    udp.listen((event) {
      if (event == RawSocketEvent.read) {
        final packet = udp.receive();
        if (packet != null) onPacket(packet);
      }
    });
    state = state.copyWith(isReady: true);
    return udp;
  }

  Future<void> _bindArtnet(int port) async {
    final udp = await _bind(port, _generation, handleData);
    if (udp == null) return;
    _udp = udp;
    state = state.copyWith(
      ip: ref.read(settingsStateProvider).controllerIpAddress,
      port: port,
    );
  }

  Future<void> _bindSacn(int universe) async {
    final generation = _generation;
    // Android drops multicast on Wi-Fi unless an app holds a MulticastLock
    await _setMulticastLock(true);
    if (generation != _generation) return;
    final udp = await _bind(sacnPort, generation, _handleSacn);
    if (udp == null) return;
    _sacnUdp = udp;
    try {
      udp.joinMulticast(sacnMulticastAddress(universe));
    } on SocketException {
      // No multicast route; unicast sACN still arrives
    }
  }

  Future<void> _setMulticastLock(bool held) async {
    if (!Platform.isAndroid) return;
    try {
      await _multicastChannel.invokeMethod(held ? 'acquire' : 'release');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  void setBroadcasting(bool value) {
    state = state.copyWith(isBroadcasting: value, isReady: true);
  }

  void handleData(Datagram data) {
    // ArtnetCheckPacket reads the 8-byte ID and the opcode without bounds checks
    if (data.data.length < 10 || !ArtnetCheckPacket(data.data)) return;

    final settings = ref.read(settingsStateProvider);
    state = state.copyWith(
      isReady: true,
      lastValidPacketTime: DateTime.now(),
      streamTerminated: false,
    );

    // Parse the packet
    final opCode = ArtnetGetOpCode(data.data);
    if (opCode == ArtnetPollPacket.opCode) {
      sendArtPollReply();
    } else if (opCode == ArtnetDataPacket.opCode) {
      final dmx = ArtnetDataPacket(packet: data.data);

      // Art-Net counts universes from 0, the settings count from 1
      if (dmx.universe != settings.universe - 1) {
        return;
      }

      _applyDmx(dmx.dmx, settings);
    }
  }

  void _handleSacn(Datagram data) {
    final packet = SacnPacket.parse(data.data);
    if (packet == null || packet.preview) return;

    final settings = ref.read(settingsStateProvider);
    if (packet.universe != settings.universe) return;

    final now = DateTime.now();
    if (!_sacnArbiter.accept(packet, now)) {
      // In Both mode Art-Net may still be live, so leave it to the timeout
      if (packet.streamTerminated &&
          !_sacnArbiter.hasSources &&
          settings.protocol == DmxProtocol.sacn) {
        state = state.copyWith(streamTerminated: true);
      }
      return;
    }

    state = state.copyWith(
      isReady: true,
      lastValidPacketTime: now,
      streamTerminated: false,
    );
    _applyDmx(packet.dmx, settings);
  }

  void _applyDmx(List<int> dmx, SettingsState settings) {
    // Both protocols allow short frames, treat missing channels as 0
    DmxChannel channel(int offset) {
      final index = settings.dmxStartChannel - 1 + offset;
      return DmxChannel(
        channel: settings.dmxStartChannel + offset,
        value: index >= 0 && index < dmx.length ? dmx[index] : 0,
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
      strobe: settings.useStrobeChannel
          ? channel(settings.strobeChannelOffset)
          : DmxChannel.unused,
    );
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
    packet.shortName = settings.deviceName;
    packet.longName = settings.deviceName;
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
