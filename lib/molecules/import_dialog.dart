import 'dart:convert';
import 'dart:typed_data';

import 'package:chromapulse/providers/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../providers/providers.dart';

class ImportConfigDialog extends StatefulHookConsumerWidget {
  const ImportConfigDialog({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ImportConfigDialogState();
}

class _ImportConfigDialogState extends ConsumerState<ImportConfigDialog> {
  SettingsState qrData = SettingsState();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      icon: const Icon(CupertinoIcons.qrcode),
      title: const Text("Export Configuration"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Place the QR Code in the box below to import a configuration from another device.",
          ),
          const SizedBox(height: 16),
          // QR Code Scanner area
          SizedBox(
            width: 200,
            height: 200,
            child: MobileScanner(
              onDetect: (barcodes) {
                if (barcodes.barcodes.isEmpty) {
                  return;
                }
                final barcode = barcodes.barcodes.first;
                final Uint8List? bytes = barcode.rawBytes;
                final json = String.fromCharCodes(bytes!);
                final settings = _decode(json);
                if (settings != null) {
                  qrData = settings;
                  ref
                      .read(settingsStateProvider.notifier)
                      .importSettings(settings);
                  Navigator.of(context).pop();
                }
              },
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
      return SettingsState();
    }
    final version = parts[0];
    final data = parts[1];
    if (version != "ChromaPulseConfigV1") {
      return SettingsState();
    }
    final decoded = base64Decode(data);
    final json = String.fromCharCodes(decoded);
    final settings = SettingsState.fromJson(json);
    return settings;
  }
}
