import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/providers.dart';
import '../setting_edit_dialog.dart';

class DeviceConfigurationTile extends StatefulHookConsumerWidget {
  const DeviceConfigurationTile({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _DeviceConfigurationTileState();
}

class _DeviceConfigurationTileState
    extends ConsumerState<DeviceConfigurationTile> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsStateProvider);
    return ExpansionTile(
      title: const Text("Device Configuration"),
      children: [
        ListTile(
          title: const Text("4-Channel Mode"),
          subtitle: const Text("Wether to use 4 channels or 3. The 4th "
              "channel is used to control device brightness."),
          trailing: Switch(
            value: settings.use4Channels,
            onChanged: (value) {
              ref.read(settingsStateProvider.notifier).setUse4Channels(value);
            },
          ),
        ),
        ListTile(
            title: const Text("DMX Channels"),
            subtitle: Text(
                "${settings.dmxStartChannel} through ${settings.dmxStartChannel + (settings.use4Channels ? 3 : 2)}"),
            trailing: IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => SettingEditDialog(
                    title: "Start DMX Channel",
                    onSave: (setting) {
                      try {
                        final channel = int.parse(setting);
                        if (channel < 1 ||
                            channel >
                                (settings.use4Channels
                                    ? (512 - 3)
                                    : (512 - 2))) {
                          throw Exception("");
                        }

                        ref
                            .read(settingsStateProvider.notifier)
                            .setDmxStartChannel(int.parse(setting));
                      } catch (e) {
                        // Show error snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Invalid channel number, enter "
                                "a number between 1 and ${(settings.use4Channels ? (512 - 3) : (512 - 2))}"),
                          ),
                        );
                      }
                    },
                    initialValue: settings.dmxStartChannel.toString(),
                  ),
                );
              },
              icon: const Icon(Icons.edit),
            )),
        ListTile(
          title: const Text("Universe"),
          subtitle: Text("Universe ${settings.universe}"),
          trailing: IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => SettingEditDialog(
                  title: "Universe",
                  onSave: (setting) {
                    try {
                      final universe = int.parse(setting);
                      if (universe < 1 || universe > 30000) {
                        throw Exception("");
                      }
                      ref
                          .read(settingsStateProvider.notifier)
                          .setUniverse(universe);
                    } catch (e) {
                      // Show error snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Invalid universe number, enter "
                              "a number between 1 and 30,000"),
                        ),
                      );
                    }
                  },
                  initialValue: settings.universe.toString(),
                ),
              );
            },
            icon: const Icon(Icons.edit),
          ),
        ),
        ListTile(
          title: const Text("Allow Broadcast"),
          subtitle: const Text("Enabling this will allow the device to "
              "listen to broadcats from the contoller."),
          trailing: Switch(
            value: settings.allowBroadcast,
            onChanged: (value) {
              ref.read(settingsStateProvider.notifier).setAllowBroadcast(value);
            },
          ),
        ),
      ],
    );
  }
}
