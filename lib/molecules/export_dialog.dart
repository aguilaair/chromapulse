import 'dart:convert';

import 'package:chromapulse/providers/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/providers.dart';

class ExportConfigDialog extends StatefulHookConsumerWidget {
  const ExportConfigDialog({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ExportConfigDialogState();
}

class _ExportConfigDialogState extends ConsumerState<ExportConfigDialog> {
  SettingsState qrData = SettingsState();
  late int numChannels;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsStateProvider);
    qrData = settings;
    numChannels = settings.use4Channels ? 4 : 3;
  }

  @override
  Widget build(BuildContext context) {
    final channelController =
        useTextEditingController(text: qrData.dmxStartChannel.toString());

    return AlertDialog(
      scrollable: true,
      icon: const Icon(CupertinoIcons.qrcode),
      title: const Text("Export Configuration"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
              "Scan this QR code with the ChromaPulse mobile app to import this configuration into another device."),
          const SizedBox(height: 16),
          SizedBox(
            width: 200,
            height: 200,
            child: QrImageView(
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: Theme.of(context).iconTheme.color!,
              ),
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.circle,
                color: Theme.of(context).iconTheme.color,
              ),
              data: _encode(qrData),
              size: 200,
            ),
          ),
          // Channel modification textbox
          const SizedBox(height: 16),
          const Text(
              "You can also modify the channel values below to change the configuration."),
          const SizedBox(height: 16),
          // Outline button to go to next channel
          OutlinedButton.icon(
            onPressed: () {
              final newChannel = qrData.dmxStartChannel + numChannels;
              setState(
                () {
                  qrData = qrData.copyWith(
                    dmxStartChannel:
                        newChannel + numChannels > 512 ? 1 : newChannel,
                  );
                  channelController.value = TextEditingValue(
                    text: qrData.dmxStartChannel.toString(),
                  );
                },
              );
            },
            icon: const Icon(CupertinoIcons.arrow_right_circle),
            label: const Text("Next Channel"),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Text("Start Channel:")),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Start Channel",
                  ),
                  controller: channelController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    if (value.isEmpty) {
                      return;
                    }
                    setState(() {
                      qrData =
                          qrData.copyWith(dmxStartChannel: int.parse(value));
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
            ],
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

  // json to base 64
  String _encode(SettingsState input) {
    final bytes = input.toJson().codeUnits;
    final base64Str = base64Encode(bytes);
    return "ChromaPulseConfigV1-$base64Str";
  }
}
