import 'package:chromapulse/molecules/config/about.dart';
import 'package:chromapulse/molecules/config/controller.dart';
import 'package:chromapulse/molecules/config/device.dart';
import 'package:chromapulse/molecules/config/network.dart';
import 'package:chromapulse/molecules/export_dialog.dart';
import 'package:chromapulse/show/show.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'molecules/import_dialog.dart';

class ConfiguationPage extends StatefulHookConsumerWidget {
  const ConfiguationPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ConfiguationPageState();
}

class _ConfiguationPageState extends ConsumerState<ConfiguationPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Go to show page
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const ShowPage(),
          ));
        },
        label: const Text("Start"),
        icon: const Icon(CupertinoIcons.play_arrow_solid),
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
                onPressed: () {
                  // Dialog with QR code
                  showDialog(
                    context: context,
                    builder: (context) => const ImportConfigDialog(),
                  );
                },
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
          const SliverList(
              delegate: SliverChildListDelegate.fixed([
            NetworkConfigTile(),
            DeviceConfigurationTile(),
            ControllerConfigurationTile(),
            AboutConfigurationTile(),
            SizedBox(height: 100),
          ])),
        ],
      ),
    );
  }
}
