import 'package:chromapulse/providers/artnet.dart';
import 'package:chromapulse/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ShowPage extends StatefulHookConsumerWidget {
  const ShowPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ShowPageState();
}

class _ShowPageState extends ConsumerState<ShowPage> {
  // Show material banner on page load
  @override
  void didChangeDependencies() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showMaterialBanner();
    });
    super.didChangeDependencies();
  }

  late ArtnetState? artnetState;
  bool _isBannerVisible = false;

  @override
  Widget build(BuildContext context) {
    artnetState = ref.watch(artnetStateProvider);
    return Scaffold(
      body: GestureDetector(
        onDoubleTap: () {
          if (_isBannerVisible) {
            return;
          }
          // Show material banner on double tap
          _showMaterialBanner();
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Container(
            color: Color.fromARGB(
              255,
              artnetState?.red.value ?? 0,
              artnetState?.green.value ?? 0,
              artnetState?.blue.value ?? 0,
            ),
          ),
        ),
      ),
    );
  }

  void _showMaterialBanner() {
    _isBannerVisible = true;
    ScaffoldMessenger.of(context).showMaterialBanner(MaterialBanner(
      content: Row(
        children: [
          Chip(
            label: Text(
              "Status: ${artnetState!.isReady ? "Ready" : "Not Ready"}",
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: artnetState!.isReady
                        ? Colors.white
                        : Theme.of(context).colorScheme.onError,
                  ),
            ),
            backgroundColor: artnetState!.isReady
                ? Colors.green
                : Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              _isBannerVisible = false;
              // Exit show page
              ScaffoldMessenger.of(context).clearMaterialBanners();
              // Delay exit to allow material banner to be removed
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) Navigator.of(context).pop();
              });
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            _isBannerVisible = false;
          },
          child: const Text("Hide"),
        ),
      ],
    ));
  }
}
