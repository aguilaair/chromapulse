import 'package:chromapulse/molecules/export_dialog.dart';
import 'package:chromapulse/molecules/setting_edit_dialog.dart';
import 'package:chromapulse/show.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'providers/providers.dart';

class ConfiguationPage extends StatefulHookConsumerWidget {
  const ConfiguationPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ConfiguationPageState();
}

class _ConfiguationPageState extends ConsumerState<ConfiguationPage> {
  String ver = "Unknown";

  @override
  void initState() {
    super.initState();
    _getVersion();
  }

  Future<void> _getVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      ver = packageInfo.version;
    });
  }

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
            title: const Text("ChromaPulse"),
            expandedHeight: 200,
            actions: [
              IconButton(
                // export config icon
                icon: const Icon(CupertinoIcons.square_arrow_down),
                tooltip: "Scan/Import Config",
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.square_arrow_up),
                tooltip: "Export Config",
                onPressed: () {
                  // Dialog with QR code
                  showDialog(
                    context: context,
                    builder: (context) => const ExportConfigDialog(),
                  );
                },
              ),
            ],
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
                  title: const Text("4-Channel Mode"),
                  subtitle: const Text("Wether to use 4 channels or 3. The 4th "
                      "channel is used to control device brightness."),
                  trailing: Switch(
                    value: settings.use4Channels,
                    onChanged: (value) {
                      ref
                          .read(settingsStateProvider.notifier)
                          .setUse4Channels(value);
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
                                    content: Text(
                                        "Invalid channel number, enter "
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
            ExpansionTile(title: const Text("About"), children: [
              ListTile(
                title: const Text("Version"),
                subtitle: Text(ver),
              ),
              const ListTile(
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
