import 'package:artcolor/molecules/setting_edit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'providers/providers.dart';

class ConfiguationPage extends StatefulHookConsumerWidget {
  const ConfiguationPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ConfiguationPageState();
}

class _ConfiguationPageState extends ConsumerState<ConfiguationPage> {
  @override
  Widget build(BuildContext context) {
    final networkInfo = ref.watch(networkStateProvider);
    final settings = ref.watch(settingsStateProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: const Text("Start"),
        icon: const Icon(Icons.play_arrow),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text("Chrome Pulse"),
            expandedHeight: 200,
          ),
          SliverList(
              delegate: SliverChildListDelegate.fixed([
            ExpansionTile(
              title: const Text("Network Information"),
              children: [
                ListTile(
                  title: const Text("SSID"),
                  subtitle: Text(networkInfo.ssid ?? "Unknown"),
                ),
                ListTile(
                  title: const Text("IP Address"),
                  subtitle: Text(networkInfo.ipAddress ?? "Unknown"),
                ),
              ],
            ),
            ExpansionTile(
              title: const Text("Device Configuration"),
              children: [
                const ListTile(
                  title: Text("Start DMX Channel"),
                  subtitle: Text("1234"),
                  trailing: Icon(Icons.edit),
                ),
                const ListTile(
                  title: Text("Universe"),
                  subtitle: Text("Universe 1"),
                  trailing: Icon(Icons.edit),
                ),
                ListTile(
                  title: const Text("Allow Broadcast"),
                  subtitle: const Text("Enabling this will allow the device to "
                      "listen to broadcats from the contoller."),
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {},
                  ),
                ),
              ],
            ),
            ExpansionTile(title: Text("Controller Configuration"), children: [
              ListTile(
                title: Text("Controller IP Address"),
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
                  icon: const Icon(Icons.edit),
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
                          ref
                              .read(settingsStateProvider.notifier)
                              .setControllerPort(int.parse(setting));
                        },
                        initialValue: settings.controllerPort.toString(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                ),
              ),
            ]),
            const ExpansionTile(title: Text("About"), children: [
              ListTile(
                title: Text("Version"),
                subtitle: Text("1.0.0 Beta"),
              ),
              ListTile(
                title: Text("Author"),
                subtitle: Text("Eduardo Moreno"),
              ),
            ]),
          ])),
        ],
      ),
    );
  }
}
