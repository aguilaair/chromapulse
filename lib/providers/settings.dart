import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SettingsState {
  final int dmxStartChannel;
  final int universe;
  final bool allowBroadcast;
  final String controllerIpAddress;
  final int controllerPort;
  final bool use4Channels;

  SettingsState({
    this.dmxStartChannel = 1,
    this.universe = 1,
    this.allowBroadcast = true,
    this.controllerIpAddress = "",
    this.controllerPort = 6454,
    this.use4Channels = true,
  });

  SettingsState copyWith({
    int? dmxStartChannel,
    int? universe,
    bool? allowBroadcast,
    String? controllerIpAddress,
    int? controllerPort,
    bool? use4Channels,
  }) {
    return SettingsState(
      dmxStartChannel: dmxStartChannel ?? this.dmxStartChannel,
      universe: universe ?? this.universe,
      allowBroadcast: allowBroadcast ?? this.allowBroadcast,
      controllerIpAddress: controllerIpAddress ?? this.controllerIpAddress,
      controllerPort: controllerPort ?? this.controllerPort,
      use4Channels: use4Channels ?? this.use4Channels,
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
    };
  }

  factory SettingsState.fromMap(Map<String, dynamic> map) {
    return SettingsState(
      dmxStartChannel: map['dmxStartChannel']?.toInt() ?? 0,
      universe: map['universe']?.toInt() ?? 0,
      allowBroadcast: map['allowBroadcast'] ?? true,
      controllerIpAddress: map['controllerIpAddress'] ?? '',
      controllerPort: map['controllerPort']?.toInt() ?? 0,
      use4Channels: map['use4Channels'] ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory SettingsState.fromJson(String source) =>
      SettingsState.fromMap(json.decode(source));

  @override
  String toString() {
    return 'SettingsState(dmxStartChannel: $dmxStartChannel, universe: $universe, allowBroadcast: $allowBroadcast, controllerIpAddress: $controllerIpAddress, controllerPort: $controllerPort, use4Channels: $use4Channels)';
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
        other.use4Channels == use4Channels;
  }

  @override
  int get hashCode {
    return dmxStartChannel.hashCode ^
        universe.hashCode ^
        allowBroadcast.hashCode ^
        controllerIpAddress.hashCode ^
        controllerPort.hashCode ^
        use4Channels.hashCode;
  }
}

class SettingsProvider extends StateNotifier<SettingsState> {
  final Ref ref;

  SettingsProvider(this.ref) : super(SettingsState()) {
    loadSettings();
  }

  static const String key = "settings";

  void setDmxStartChannel(int value) {
    state = SettingsState(
      dmxStartChannel: value,
      universe: state.universe,
      allowBroadcast: state.allowBroadcast,
      controllerIpAddress: state.controllerIpAddress,
      controllerPort: state.controllerPort,
    );
    saveSettings();
  }

  void setUniverse(int value) {
    state = SettingsState(
      dmxStartChannel: state.dmxStartChannel,
      universe: value,
      allowBroadcast: state.allowBroadcast,
      controllerIpAddress: state.controllerIpAddress,
      controllerPort: state.controllerPort,
    );
    saveSettings();
  }

  void setAllowBroadcast(bool value) {
    state = SettingsState(
      dmxStartChannel: state.dmxStartChannel,
      universe: state.universe,
      allowBroadcast: value,
      controllerIpAddress: state.controllerIpAddress,
      controllerPort: state.controllerPort,
    );
    saveSettings();
  }

  void setControllerIpAddress(String value) {
    state = SettingsState(
      dmxStartChannel: state.dmxStartChannel,
      universe: state.universe,
      allowBroadcast: state.allowBroadcast,
      controllerIpAddress: value,
      controllerPort: state.controllerPort,
    );
    saveSettings();
  }

  void setControllerPort(int value) {
    state = SettingsState(
      dmxStartChannel: state.dmxStartChannel,
      universe: state.universe,
      allowBroadcast: state.allowBroadcast,
      controllerIpAddress: state.controllerIpAddress,
      controllerPort: value,
    );
    saveSettings();
  }

  void setUse4Channels(bool value) {
    state = SettingsState(
      dmxStartChannel: state.dmxStartChannel,
      universe: state.universe,
      allowBroadcast: state.allowBroadcast,
      controllerIpAddress: state.controllerIpAddress,
      controllerPort: state.controllerPort,
      use4Channels: value,
    );
    saveSettings();
  }

  void reset() {
    state = SettingsState();
    saveSettings();
  }

  void saveSettings() {
    // Uses Hive
    Hive.box(key).put(key, state.toJson());
  }

  void importSettings(SettingsState settings) {
    state = settings;
    saveSettings();
  }

  void loadSettings() {
    // Uses Hive
    final box = Hive.box(key);
    if (box.containsKey(key)) {
      state = SettingsState.fromJson(box.get(key));
    }
  }
}
