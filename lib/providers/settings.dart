import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum DmxProtocol {
  artnet('Art-Net'),
  sacn('sACN'),
  both('Both');

  const DmxProtocol(this.label);

  final String label;

  bool get receivesArtnet => this != sacn;
  bool get receivesSacn => this != artnet;
}

class SettingsState {
  final int dmxStartChannel;
  final int universe;
  final bool allowBroadcast;
  final String controllerIpAddress;
  final int controllerPort;
  final bool use4Channels;
  final bool useTorchChannel;
  final DmxProtocol protocol;
  final String deviceName;

  static const defaultDeviceName = 'ChromaPulse';

  /// Art-Net ShortName holds 18 bytes including the NUL, so 17 characters
  /// show up on consoles exactly as typed.
  static const deviceNameMaxLength = 17;

  SettingsState({
    this.dmxStartChannel = 1,
    this.universe = 1,
    this.allowBroadcast = true,
    this.controllerIpAddress = "",
    this.controllerPort = 6454,
    this.use4Channels = true,
    this.useTorchChannel = false,
    this.protocol = DmxProtocol.artnet,
    this.deviceName = defaultDeviceName,
  });

  /// Number of consecutive DMX channels this device listens to.
  int get channelCount =>
      3 + (use4Channels ? 1 : 0) + (useTorchChannel ? 1 : 0);

  /// Offset of the torch channel from [dmxStartChannel].
  int get torchChannelOffset => use4Channels ? 4 : 3;

  /// Whether every channel from [dmxStartChannel] fits inside one universe.
  bool get fitsUniverse =>
      dmxStartChannel >= 1 && dmxStartChannel + channelCount - 1 <= 512;

  SettingsState copyWith({
    int? dmxStartChannel,
    int? universe,
    bool? allowBroadcast,
    String? controllerIpAddress,
    int? controllerPort,
    bool? use4Channels,
    bool? useTorchChannel,
    DmxProtocol? protocol,
    String? deviceName,
  }) {
    return SettingsState(
      dmxStartChannel: dmxStartChannel ?? this.dmxStartChannel,
      universe: universe ?? this.universe,
      allowBroadcast: allowBroadcast ?? this.allowBroadcast,
      controllerIpAddress: controllerIpAddress ?? this.controllerIpAddress,
      controllerPort: controllerPort ?? this.controllerPort,
      use4Channels: use4Channels ?? this.use4Channels,
      useTorchChannel: useTorchChannel ?? this.useTorchChannel,
      protocol: protocol ?? this.protocol,
      deviceName: deviceName ?? this.deviceName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dmxStartChannel': dmxStartChannel,
      'universe': universe,
      'allowBroadcast': allowBroadcast,
      'controllerIpAddress': controllerIpAddress,
      'controllerPort': controllerPort,
      'use4Channels': use4Channels,
      'useTorchChannel': useTorchChannel,
      'protocol': protocol.name,
      'deviceName': deviceName,
    };
  }

  factory SettingsState.fromMap(Map<String, dynamic> map) {
    return SettingsState(
      dmxStartChannel: map['dmxStartChannel']?.toInt() ?? 1,
      universe: map['universe']?.toInt() ?? 1,
      allowBroadcast: map['allowBroadcast'] ?? true,
      controllerIpAddress: map['controllerIpAddress'] ?? '',
      controllerPort: map['controllerPort']?.toInt() ?? 6454,
      use4Channels: map['use4Channels'] ?? true,
      useTorchChannel: map['useTorchChannel'] ?? false,
      protocol:
          DmxProtocol.values.asNameMap()[map['protocol']] ?? DmxProtocol.artnet,
      deviceName: map['deviceName'] ?? defaultDeviceName,
    );
  }

  String toJson() => json.encode(toMap());

  String toSharedJson() => json.encode(toMap()..remove('deviceName'));

  /// Returns the trimmed name if it is 1 to [deviceNameMaxLength] printable
  /// ASCII characters, which is all Art-Net can carry.
  static String? parseDeviceName(String input) {
    final name = input.trim();
    if (name.isEmpty || name.length > deviceNameMaxLength) return null;
    final printable = name.codeUnits.every((c) => c >= 0x20 && c <= 0x7E);
    return printable ? name : null;
  }

  factory SettingsState.fromJson(String source) =>
      SettingsState.fromMap(json.decode(source));

  @override
  String toString() {
    return 'SettingsState(dmxStartChannel: $dmxStartChannel, universe: $universe, allowBroadcast: $allowBroadcast, controllerIpAddress: $controllerIpAddress, controllerPort: $controllerPort, use4Channels: $use4Channels, useTorchChannel: $useTorchChannel, protocol: $protocol, deviceName: $deviceName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SettingsState &&
        other.dmxStartChannel == dmxStartChannel &&
        other.universe == universe &&
        other.allowBroadcast == allowBroadcast &&
        other.controllerIpAddress == controllerIpAddress &&
        other.controllerPort == controllerPort &&
        other.use4Channels == use4Channels &&
        other.useTorchChannel == useTorchChannel &&
        other.protocol == protocol &&
        other.deviceName == deviceName;
  }

  @override
  int get hashCode {
    return dmxStartChannel.hashCode ^
        universe.hashCode ^
        allowBroadcast.hashCode ^
        controllerIpAddress.hashCode ^
        controllerPort.hashCode ^
        use4Channels.hashCode ^
        useTorchChannel.hashCode ^
        protocol.hashCode ^
        deviceName.hashCode;
  }
}

class SettingsProvider extends Notifier<SettingsState> {
  static const String key = "settings";

  @override
  SettingsState build() {
    final box = Hive.box(key);
    if (box.containsKey(key)) {
      return SettingsState.fromJson(box.get(key));
    }
    return SettingsState();
  }

  void _update(SettingsState value) {
    state = value;
    saveSettings();
  }

  void setDmxStartChannel(int value) =>
      _update(state.copyWith(dmxStartChannel: value));

  void setUniverse(int value) => _update(state.copyWith(universe: value));

  void setAllowBroadcast(bool value) =>
      _update(state.copyWith(allowBroadcast: value));

  void setControllerIpAddress(String value) =>
      _update(state.copyWith(controllerIpAddress: value));

  void setControllerPort(int value) =>
      _update(state.copyWith(controllerPort: value));

  void setUse4Channels(bool value) =>
      _update(state.copyWith(use4Channels: value));

  void setUseTorchChannel(bool value) =>
      _update(state.copyWith(useTorchChannel: value));

  void setProtocol(DmxProtocol value) =>
      _update(state.copyWith(protocol: value));

  void setDeviceName(String value) =>
      _update(state.copyWith(deviceName: value));

  void reset() => _update(SettingsState());

  void saveSettings() {
    // Uses Hive
    Hive.box(key).put(key, state.toJson());
  }

  void importSettings(SettingsState settings) =>
      _update(settings.copyWith(deviceName: state.deviceName));
}
