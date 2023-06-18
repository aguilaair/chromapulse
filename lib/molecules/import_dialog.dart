import 'dart:convert';
import 'dart:typed_data';

import 'package:chromapulse/providers/providers.dart';
import 'package:chromapulse/providers/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

class ImportConfigDialog extends StatefulHookConsumerWidget {
  const ImportConfigDialog({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ImportConfigDialogState();
}

class _ImportConfigDialogState extends ConsumerState<ImportConfigDialog> {
  SettingsState qrData = SettingsState();
  bool success = false;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      icon: success
          ? const Icon(CupertinoIcons.check_mark_circled)
          : const Icon(CupertinoIcons.qrcode),
      title: const Text("Import Configuration"),
      content: success
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Configuration imported successfully!",
                ),
                const SizedBox(height: 16),
                // IP Address
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Controller Address: "),
                    Text(
                      "${qrData.controllerIpAddress}:${qrData.controllerPort}",
                    ),
                  ],
                ),
                // Universe
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Universe: "),
                    Text(qrData.universe.toString()),
                  ],
                ),
                // DMX Start Channel
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("DMX Start Channel: "),
                    Text(qrData.dmxStartChannel.toString()),
                  ],
                ),
                // Use 4 Channels
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Use 4 Channels: "),
                    Icon(
                      qrData.use4Channels
                          ? CupertinoIcons.check_mark_circled
                          : CupertinoIcons.xmark_circle,
                      size: Theme.of(context).textTheme.bodyMedium!.fontSize,
                    )
                  ],
                ),
                // Allow Broadcast
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Allow Broadcast: "),
                    Icon(
                      qrData.allowBroadcast
                          ? CupertinoIcons.check_mark_circled
                          : CupertinoIcons.xmark_circle,
                      size: Theme.of(context).textTheme.bodyMedium!.fontSize,
                    )
                  ],
                ),
                // Import data version
                const Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Config Version: "),
                    Text("v1.0.0"),
                  ],
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Place the QR Code in the box below to import a configuration from another device.",
                ),
                const SizedBox(height: 16),
                // QR Code Scanner area
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: NativeDeviceOrientationReader(
                      builder: (context) {
                        final orientation =
                            NativeDeviceOrientationReader.orientation(context);
                        int turns = 0;

                        switch (orientation) {
                          case NativeDeviceOrientation.landscapeLeft:
                            turns = -1;
                            break;
                          case NativeDeviceOrientation.landscapeRight:
                            turns = 1;
                            break;
                          case NativeDeviceOrientation.portraitDown:
                            turns = 2;
                            break;
                          default:
                            turns = 0;
                            break;
                        }

                        return RotatedBox(
                          quarterTurns: turns,
                          child: MobileScanner(
                            onDetect: (barcodes) {
                              if (barcodes.barcodes.isEmpty) {
                                return;
                              }
                              final barcode = barcodes.barcodes.first;
                              final Uint8List? bytes = barcode.rawBytes;
                              final json = String.fromCharCodes(bytes!);
                              SettingsState? settings;
                              try {
                                settings = _decode(json);
                              } catch (e) {
                                return;
                              }
                              if (settings != null) {
                                qrData = settings;
                                ref
                                    .read(settingsStateProvider.notifier)
                                    .importSettings(settings);
                                setState(() {
                                  success = true;
                                });
                              }
                            },
                            placeholderBuilder: (context, size) {
                              return const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // loading indicator
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text("Initializing Camera..."),
                                ],
                              );
                            },
                            errorBuilder: (context, error, widget) {
                              return const Center(
                                child: Text("Error initializing camera.\n"
                                    "Please check your camera permissions."),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text("Close"),
        ),
      ],
    );
  }

  SettingsState? _decode(String input) {
    final parts = input.split("-");
    if (parts.length != 2) {
      throw Exception("Invalid config struct");
    }
    final version = parts[0];
    final data = parts[1];
    if (version != "ChromaPulseConfigV1") {
      throw Exception("Invalid config version");
    }
    final decoded = base64Decode(data);
    final json = String.fromCharCodes(decoded);
    final settings = SettingsState.fromJson(json);
    return settings;
  }
}
