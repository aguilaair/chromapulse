import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SettingsState {
  final int dmxStartChannel;
  final int universe;
  final bool allowBroadcast;
  final String controllerIpAddress;
  final int controllerPort;

  SettingsState({
    this.dmxStartChannel = 1,
    this.universe = 1,
    this.allowBroadcast = true,
    this.controllerIpAddress = "",
    this.controllerPort = 1936,
  });

  SettingsState copyWith({
    int? dmxStartChannel,
    int? universe,
    bool? allowBroadcast,
    String? controllerIpAddress,
    int? controllerPort,
  }) {
    return SettingsState(
      dmxStartChannel: dmxStartChannel ?? this.dmxStartChannel,
      universe: universe ?? this.universe,
      allowBroadcast: allowBroadcast ?? this.allowBroadcast,
      controllerIpAddress: controllerIpAddress ?? this.controllerIpAddress,
      controllerPort: controllerPort ?? this.controllerPort,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dmxStartChannel': dmxStartChannel,
      'universe': universe,
      'allowBroadcast': allowBroadcast,
      'controllerIpAddress': controllerIpAddress,
      'controllerPort': controllerPort,
    };
  }

  factory SettingsState.fromMap(Map<String, dynamic> map) {
    return SettingsState(
      dmxStartChannel: map['dmxStartChannel'] ?? '',
      universe: map['universe'] ?? '',
      allowBroadcast: map['allowBroadcast'] ?? false,
      controllerIpAddress: map['controllerIpAddress'] ?? '',
      controllerPort: map['controllerPort']?.toInt() ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory SettingsState.fromJson(String source) =>
      SettingsState.fromMap(json.decode(source));

  @override
  String toString() {
    return 'SettingsState(dmxStartChannel: $dmxStartChannel, universe: $universe, allowBroadcast: $allowBroadcast, controllerIpAddress: $controllerIpAddress, controllerPort: $controllerPort)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SettingsState &&
        other.dmxStartChannel == dmxStartChannel &&
        other.universe == universe &&
        other.allowBroadcast == allowBroadcast &&
        other.controllerIpAddress == controllerIpAddress &&
        other.controllerPort == controllerPort;
  }

  @override
  int get hashCode {
    return dmxStartChannel.hashCode ^
        universe.hashCode ^
        allowBroadcast.hashCode ^
        controllerIpAddress.hashCode ^
        controllerPort.hashCode;
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

  void reset() {
    state = SettingsState();
    saveSettings();
  }

  void saveSettings() {
    // Uses Hive
    Hive.box(key).put(key, state.toJson());
  }

  void loadSettings() {
    // Uses Hive
    final box = Hive.box(key);
    if (box.containsKey(key)) {
      state = SettingsState.fromJson(box.get(key));
    }
  }
}
