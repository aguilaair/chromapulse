//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import mobile_scanner
import network_info_plus
import package_info_plus
import path_provider_foundation
import screen_brightness_macos
import wakelock_macos

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  MobileScannerPlugin.register(with: registry.registrar(forPlugin: "MobileScannerPlugin"))
  NetworkInfoPlusPlugin.register(with: registry.registrar(forPlugin: "NetworkInfoPlusPlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  PathProviderPlugin.register(with: registry.registrar(forPlugin: "PathProviderPlugin"))
  ScreenBrightnessMacosPlugin.register(with: registry.registrar(forPlugin: "ScreenBrightnessMacosPlugin"))
  WakelockMacosPlugin.register(with: registry.registrar(forPlugin: "WakelockMacosPlugin"))
}
