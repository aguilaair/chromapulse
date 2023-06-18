import 'dart:convert';
import 'dart:math';

import 'package:chromapulse/providers/providers.dart';
import 'package:chromapulse/providers/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  void initState() {
    super.initState();
    // Lock orientation to portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    // Unlock orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

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
                    Text("v1"),
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
                    child: MobileScanner(
                      onDetect: (barcodes) async {
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

                        //Emulate Face ID scan feedpack
                        HapticFeedback.mediumImpact();
                        Future.delayed(const Duration(milliseconds: 100), () {
                          HapticFeedback.heavyImpact();
                        });

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
