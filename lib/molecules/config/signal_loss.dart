import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/providers.dart';
import '../../providers/settings.dart';
import '../setting_edit_dialog.dart';

class SignalLossConfigTile extends StatefulHookConsumerWidget {
  const SignalLossConfigTile({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _SignalLossConfigTileState();
}

class _SignalLossConfigTileState extends ConsumerState<SignalLossConfigTile> {
  static const _labels = {
    SignalLossAction.hold: "Hold last look",
    SignalLossAction.blackout: "Black out",
    SignalLossAction.fade: "Fade to black",
    SignalLossAction.colour: "Show colour",
  };

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsStateProvider);
    final notifier = ref.read(settingsStateProvider.notifier);
    final hex = settings.signalLossColor
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    return ExpansionTile(
      title: const Text("Signal Loss"),
      children: [
        ListTile(
          title: const Text("When Signal Is Lost"),
          trailing: DropdownButton<SignalLossAction>(
            value: settings.signalLossAction,
            onChanged: (value) {
              if (value != null) notifier.setSignalLossAction(value);
            },
            items: [
              for (final entry in _labels.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
          ),
        ),
        ListTile(
          title: const Text("Timeout"),
          subtitle: Text(
            "After ${settings.signalLossTimeout} seconds without packets",
          ),
          trailing: IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => SettingEditDialog(
                  title: "Timeout (seconds)",
                  onSave: (setting) {
                    try {
                      final seconds = int.parse(setting);
                      if (seconds < 1 || seconds > 60) {
                        throw Exception("");
                      }
                      notifier.setSignalLossTimeout(seconds);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Invalid timeout, enter "
                            "a number between 1 and 60",
                          ),
                        ),
                      );
                    }
                  },
                  initialValue: settings.signalLossTimeout.toString(),
                ),
              );
            },
            icon: const Icon(CupertinoIcons.pen),
          ),
        ),
        if (settings.signalLossAction == SignalLossAction.colour)
          ListTile(
            leading: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF000000 | settings.signalLossColor),
                border: Border.all(color: Colors.white54),
              ),
            ),
            title: const Text("Colour"),
            subtitle: Text("#$hex"),
            trailing: IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => SettingEditDialog(
                    title: "Colour (hex)",
                    onSave: (setting) {
                      final value = setting.trim().replaceFirst('#', '');
                      final color = RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)
                          ? int.parse(value, radix: 16)
                          : null;
                      if (color == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Invalid colour, enter "
                              "a 6-digit hex value like #FF8800",
                            ),
                          ),
                        );
                        return;
                      }
                      notifier.setSignalLossColor(color);
                    },
                    initialValue: "#$hex",
                  ),
                );
              },
              icon: const Icon(CupertinoIcons.pen),
            ),
          ),
      ],
    );
  }
}
