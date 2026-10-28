import 'package:chromapulse/providers/artnet.dart';
import 'package:chromapulse/providers/network.dart';
import 'package:chromapulse/providers/settings.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final networkStateProvider =
    NotifierProvider.autoDispose<NetworkProvider, NetworkState>(
      NetworkProvider.new,
    );

final settingsStateProvider =
    NotifierProvider.autoDispose<SettingsProvider, SettingsState>(
      SettingsProvider.new,
    );

final artnetStateProvider =
    NotifierProvider.autoDispose<ArtnetProvider, ArtnetState>(
      ArtnetProvider.new,
    );
