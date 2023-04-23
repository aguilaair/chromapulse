import 'package:chromapulse/providers/artnet.dart';
import 'package:chromapulse/providers/network.dart';
import 'package:chromapulse/providers/settings.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final networkStateProvider =
    StateNotifierProvider.autoDispose<NetworkProvider, NetworkState>((ref) {
  return NetworkProvider(ref);
});

final settingsStateProvider =
    StateNotifierProvider.autoDispose<SettingsProvider, SettingsState>((ref) {
  return SettingsProvider(ref);
});

final artnetStateProvider =
    StateNotifierProvider.autoDispose<ArtnetProvider, ArtnetState>((ref) {
  return ArtnetProvider(ref);
});
