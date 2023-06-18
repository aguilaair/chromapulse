import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/providers.dart';
import '../setting_edit_dialog.dart';

class ControllerConfigurationTile extends StatefulHookConsumerWidget {
  const ControllerConfigurationTile({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ControllerConfigurationTileState();
}

class _ControllerConfigurationTileState
    extends ConsumerState<ControllerConfigurationTile> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsStateProvider);
    return ExpansionTile(
      title: const Text("Controller Configuration"),
      children: [
        ListTile(
          title: const Text("Controller IP Address"),
          subtitle: Text(settings.controllerIpAddress),
          trailing: IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => SettingEditDialog(
                  title: "Controller IP Address",
                  onSave: (setting) {
                    ref
                        .read(settingsStateProvider.notifier)
                        .setControllerIpAddress(setting);
                  },
                  initialValue: settings.controllerIpAddress,
                ),
              );
            },
            icon: const Icon(CupertinoIcons.pen),
          ),
        ),
        ListTile(
          title: const Text("Controller Port"),
          subtitle: Text(settings.controllerPort.toString()),
          trailing: IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => SettingEditDialog(
                  title: "Controller Port",
                  onSave: (setting) {
                    try {
                      if (int.parse(setting) < 1 ||
                          int.parse(setting) > 65535) {
                        throw Exception("");
                      }
                      ref
                          .read(settingsStateProvider.notifier)
                          .setControllerPort(int.parse(setting));
                    } catch (e) {
                      // Show error snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Invalid port number, enter "
                              "a number between 1 and 65535"),
                        ),
                      );
                    }
                  },
                  initialValue: settings.controllerPort.toString(),
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
