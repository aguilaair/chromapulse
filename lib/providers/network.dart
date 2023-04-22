import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkState {
  final String? ipAddress;
  final String? macAddress;
  final String? ssid;
  final String? bssid;
  final String? subnet;
  final String? gateway;

  final bool isReady;

  NetworkState({
    this.ipAddress,
    this.macAddress,
    this.ssid,
    this.bssid,
    this.subnet,
    this.gateway,
    this.isReady = false,
  });
}

class NetworkProvider extends StateNotifier<NetworkState> {
  final Ref ref;

  NetworkProvider(this.ref) : super(NetworkState()) {
    _init();
  }

  Future<void> _init() async {
    final networkInfo = NetworkInfo();
    final ipAddress = await networkInfo.getWifiIP();
    final macAddress = await networkInfo.getWifiBSSID();
    final ssid = await networkInfo.getWifiName();
    final bssid = await networkInfo.getWifiBSSID();
    final subnet = await networkInfo.getWifiIP();
    final gateway = await networkInfo.getWifiIP();

    state = NetworkState(
      ipAddress: ipAddress,
      macAddress: macAddress,
      ssid: ssid,
      bssid: bssid,
      subnet: subnet,
      gateway: gateway,
      isReady: true,
    );
  }
}
