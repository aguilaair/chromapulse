import 'dart:convert';

import 'package:chromapulse/dimmer.dart';
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

enum SignalLossAction { hold, blackout, fade, colour }

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
  final SignalLossAction signalLossAction;
  final int signalLossTimeout;
  final int signalLossColor;
  final DimmerCurve dimmerCurve;
  final bool curveRgb;
  final int fadeTimeMs;

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
    this.signalLossAction = SignalLossAction.hold,
    this.signalLossTimeout = 4,
    this.signalLossColor = 0xFFFFFF,
    this.dimmerCurve = DimmerCurve.linear,
    this.curveRgb = false,
    this.fadeTimeMs = 0,
  });

  /// Number of consecutive DMX channels this device listens to.
  int get channelCount =>
      3 + (use4Channels ? 1 : 0) + (useTorchChannel ? 1 : 0);

  /// Offset of the torch channel from [dmxStartChannel].
  int get torchChannelOffset => use4Channels ? 4 : 3;

  /// Whether every channel from [dmxStartChannel] fits inside one universe.
  bool get fitsUniverse =>
      dmxStartChannel >= 1 && dmxStartChannel + channelCount - 1 <= 512;

  bool isSignalLost(DateTime? lastPacket, DateTime now) =>
      lastPacket == null ||
      now.difference(lastPacket) >= Duration(seconds: signalLossTimeout);

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
    SignalLossAction? signalLossAction,
    int? signalLossTimeout,
    int? signalLossColor,
    DimmerCurve? dimmerCurve,
    bool? curveRgb,
    int? fadeTimeMs,
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
      signalLossAction: signalLossAction ?? this.signalLossAction,
      signalLossTimeout: signalLossTimeout ?? this.signalLossTimeout,
      signalLossColor: signalLossColor ?? this.signalLossColor,
      dimmerCurve: dimmerCurve ?? this.dimmerCurve,
      curveRgb: curveRgb ?? this.curveRgb,
      fadeTimeMs: fadeTimeMs ?? this.fadeTimeMs,
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
      'signalLossAction': signalLossAction.name,
      'signalLossTimeout': signalLossTimeout,
      'signalLossColor': signalLossColor,
      'dimmerCurve': dimmerCurve.name,
      'curveRgb': curveRgb,
      'fadeTimeMs': fadeTimeMs,
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
      signalLossAction:
          SignalLossAction.values.asNameMap()[map['signalLossAction']] ??
          SignalLossAction.hold,
      signalLossTimeout: (map['signalLossTimeout']?.toInt() ?? 4).clamp(1, 60),
      signalLossColor: (map['signalLossColor']?.toInt() ?? 0xFFFFFF) & 0xFFFFFF,
      dimmerCurve: DimmerCurve.fromName(map['dimmerCurve']),
      curveRgb: map['curveRgb'] ?? false,
      fadeTimeMs: map['fadeTimeMs']?.toInt() ?? 0,
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
    return 'SettingsState(dmxStartChannel: $dmxStartChannel, universe: $universe, allowBroadcast: $allowBroadcast, controllerIpAddress: $controllerIpAddress, controllerPort: $controllerPort, use4Channels: $use4Channels, useTorchChannel: $useTorchChannel, protocol: $protocol, deviceName: $deviceName, signalLossAction: $signalLossAction, signalLossTimeout: $signalLossTimeout, signalLossColor: $signalLossColor, dimmerCurve: $dimmerCurve, curveRgb: $curveRgb, fadeTimeMs: $fadeTimeMs)';
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
        other.deviceName == deviceName &&
        other.signalLossAction == signalLossAction &&
        other.signalLossTimeout == signalLossTimeout &&
        other.signalLossColor == signalLossColor &&
        other.dimmerCurve == dimmerCurve &&
        other.curveRgb == curveRgb &&
        other.fadeTimeMs == fadeTimeMs;
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
        deviceName.hashCode ^
        signalLossAction.hashCode ^
        signalLossTimeout.hashCode ^
        signalLossColor.hashCode ^
        dimmerCurve.hashCode ^
        curveRgb.hashCode ^
        fadeTimeMs.hashCode;
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

  void setDimmerCurve(DimmerCurve value) =>
      _update(state.copyWith(dimmerCurve: value));

  void setCurveRgb(bool value) => _update(state.copyWith(curveRgb: value));

  void setFadeTimeMs(int value) => _update(state.copyWith(fadeTimeMs: value));

  void setDeviceName(String value) =>
      _update(state.copyWith(deviceName: value));

  void setSignalLossAction(SignalLossAction value) =>
      _update(state.copyWith(signalLossAction: value));

  void setSignalLossTimeout(int value) =>
      _update(state.copyWith(signalLossTimeout: value));

  void setSignalLossColor(int value) =>
      _update(state.copyWith(signalLossColor: value));

  void reset() => _update(SettingsState());

  void saveSettings() {
    // Uses Hive
    Hive.box(key).put(key, state.toJson());
  }

  void importSettings(SettingsState settings) =>
      _update(settings.copyWith(deviceName: state.deviceName));
}
