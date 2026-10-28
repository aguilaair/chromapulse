import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/providers.dart';
import '../../providers/settings.dart';
import '../setting_edit_dialog.dart';

class DeviceConfigurationTile extends StatefulHookConsumerWidget {
  const DeviceConfigurationTile({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _DeviceConfigurationTileState();
}

class _DeviceConfigurationTileState
    extends ConsumerState<DeviceConfigurationTile> {
  bool _fits(SettingsState next) {
    if (next.fitsUniverse) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Not enough channels left in the universe, set the start "
          "channel to ${512 - next.channelCount + 1} or lower first",
        ),
      ),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsStateProvider);
    final maxStartChannel = 512 - settings.channelCount + 1;
    return ExpansionTile(
      title: const Text("Device Configuration"),
      children: [
        ListTile(
          title: const Text("Device Name"),
          subtitle: Text(settings.deviceName),
          trailing: IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => SettingEditDialog(
                  title: "Device Name",
                  onSave: (setting) {
                    final name = SettingsState.parseDeviceName(setting);
                    if (name == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Enter 1 to ${SettingsState.deviceNameMaxLength} "
                            "letters, numbers or symbols",
                          ),
                        ),
                      );
                      return;
                    }
                    ref
                        .read(settingsStateProvider.notifier)
                        .setDeviceName(name);
                  },
                  initialValue: settings.deviceName,
                  maxLength: SettingsState.deviceNameMaxLength,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[ -~]')),
                  ],
                ),
              );
            },
            icon: const Icon(CupertinoIcons.pen),
          ),
        ),
        ListTile(
          title: const Text("4-Channel Mode"),
          subtitle: const Text(
            "Wether to use 4 channels or 3. The 4th "
            "channel is used to control device brightness.",
          ),
          trailing: Switch(
            value: settings.use4Channels,
            onChanged: (value) {
              if (!_fits(settings.copyWith(use4Channels: value))) return;
              ref.read(settingsStateProvider.notifier).setUse4Channels(value);
            },
          ),
        ),
        ListTile(
          title: const Text("Torch Channel"),
          subtitle: Text(
            "Adds a channel after "
            "${settings.use4Channels ? "brightness" : "blue"} that "
            "turns the camera flash on at 50% or higher.",
          ),
          trailing: Switch(
            value: settings.useTorchChannel,
            onChanged: (value) {
              if (!_fits(settings.copyWith(useTorchChannel: value))) return;
              ref
                  .read(settingsStateProvider.notifier)
                  .setUseTorchChannel(value);
            },
          ),
        ),
        ListTile(
          title: const Text("DMX Channels"),
          subtitle: Text(
            "${settings.dmxStartChannel} through ${settings.dmxStartChannel + settings.channelCount - 1}",
          ),
          trailing: IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => SettingEditDialog(
                  title: "Start DMX Channel",
                  onSave: (setting) {
                    try {
                      final channel = int.parse(setting);
                      if (channel < 1 || channel > maxStartChannel) {
                        throw Exception("");
                      }

                      ref
                          .read(settingsStateProvider.notifier)
                          .setDmxStartChannel(int.parse(setting));
                    } catch (e) {
                      // Show error snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Invalid channel number, enter "
                            "a number between 1 and $maxStartChannel",
                          ),
                        ),
                      );
                    }
                  },
                  initialValue: settings.dmxStartChannel.toString(),
                ),
              );
            },
            icon: const Icon(CupertinoIcons.pen),
          ),
        ),
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
                          content: Text(
                            "Invalid universe number, enter "
                            "a number between 1 and 30,000",
                          ),
                        ),
                      );
                    }
                  },
                  initialValue: settings.universe.toString(),
                ),
              );
            },
            icon: const Icon(CupertinoIcons.pen),
          ),
        ),
        ListTile(
          title: const Text("Allow Broadcast"),
          subtitle: const Text(
            "Enabling this will allow the device to "
            "listen to broadcats from the contoller.",
          ),
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
