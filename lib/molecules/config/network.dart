import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/providers.dart';

class NetworkConfigTile extends StatefulHookConsumerWidget {
  const NetworkConfigTile({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _NetworkConfigTileState();
}

class _NetworkConfigTileState extends ConsumerState<NetworkConfigTile> {
  @override
  Widget build(BuildContext context) {
    final networkInfo = ref.watch(networkStateProvider);
    return ExpansionTile(
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
    );
  }
}
