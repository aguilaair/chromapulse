import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutConfigurationTile extends StatefulWidget {
  const AboutConfigurationTile({super.key});

  @override
  State<AboutConfigurationTile> createState() => _AboutConfigurationTileState();
}

class _AboutConfigurationTileState extends State<AboutConfigurationTile> {
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
    return ExpansionTile(title: const Text("About"), children: [
      ListTile(
        title: const Text("Version"),
        subtitle: Text(ver),
      ),
      const ListTile(
        title: Text("Author"),
        subtitle: Text("Eduardo Moreno"),
      ),
      AboutListTile(
        applicationName: "ChromaPulse",
        applicationVersion: ver,
        applicationIcon: Image.asset(
          "assets/icon/macos.png",
          width: 64,
          height: 64,
        ),
        applicationLegalese: "© 2024 Eduardo Moreno",
        aboutBoxChildren: const [
          Text(
            "This application is open source and licensed under the MIT license."
            "\n\nFork it, twist it, flip it or follow me on GitHub.",
          ),
        ],
      ),
    ]);
  }
}
