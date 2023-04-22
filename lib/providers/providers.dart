import 'package:artcolor/providers/network.dart';
import 'package:artcolor/providers/settings.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final networkStateProvider =
    StateNotifierProvider.autoDispose<NetworkProvider, NetworkState>((ref) {
  return NetworkProvider(ref);
});


final settingsStateProvider =
    StateNotifierProvider.autoDispose<SettingsProvider, SettingsState>((ref) {
  return SettingsProvider(ref);
});