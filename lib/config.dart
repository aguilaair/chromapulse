import 'package:artcolor/molecules/setting_edit_dialog.dart';
import 'package:artcolor/show.dart';
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
        onPressed: () {
          // Go to show page
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const ShowPage(),
          ));
        },
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
                ListTile(
                    title: const Text("Start DMX Channel"),
                    subtitle: Text(settings.dmxStartChannel.toString()),
                    trailing: IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => SettingEditDialog(
                            title: "Start DMX Channel",
                            onSave: (setting) {
                              try {
                                final channel = int.parse(setting);
                                if (channel < 1 || channel > 512 - 3) {
                                  throw Exception("");
                                }

                                ref
                                    .read(settingsStateProvider.notifier)
                                    .setDmxStartChannel(int.parse(setting));
                              } catch (e) {
                                // Show error snackbar
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text("Invalid channel number, enter "
                                            "a number between 1 and 509"),
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
                                  content:
                                      Text("Invalid universe number, enter "
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
                      ref
                          .read(settingsStateProvider.notifier)
                          .setAllowBroadcast(value);
                    },
                  ),
                ),
              ],
            ),
            ExpansionTile(
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
