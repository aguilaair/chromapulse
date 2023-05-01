import 'package:chromapulse/providers/artnet.dart';
import 'package:chromapulse/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock/wakelock.dart';

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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    Wakelock.enable();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    ScreenBrightness().resetScreenBrightness();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Wakelock.disable();
    super.dispose();
  }

  late ArtnetState? artnetState;
  bool _isBannerVisible = false;
  int lastBrightness = -1;

  @override
  Widget build(BuildContext context) {
    artnetState = ref.watch(artnetStateProvider);
    final is4Channel = ref.read(settingsStateProvider).use4Channels;
    if (is4Channel) {
      if (lastBrightness == -1 && artnetState?.brightness.value != null) {
        lastBrightness = artnetState?.brightness.value ?? 0;
        ScreenBrightness().setScreenBrightness(lastBrightness / 255);
      } else if (artnetState?.brightness.value != null &&
          lastBrightness != (artnetState!.brightness.value)) {
        lastBrightness = artnetState?.brightness.value ?? 0;
        ScreenBrightness().setScreenBrightness(lastBrightness / 255);
      }
    }
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
          const StatusBadge(),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              _isBannerVisible = false;
              // Exit show page
              ScaffoldMessenger.of(context).clearMaterialBanners();
              // Delay exit to allow material banner to be removed
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) Navigator.of(context).pop();
                ref.read(artnetStateProvider.notifier).dispose();
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

class StatusBadge extends HookConsumerWidget {
  const StatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artnetState = ref.watch(artnetStateProvider);
    return Chip(
      label: Text(
        "Status: ${artnetState.isReady ? "Ready" : "Not Ready"}",
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: artnetState.isReady
                  ? Colors.white
                  : Theme.of(context).colorScheme.onError,
            ),
      ),
      backgroundColor: artnetState.isReady
          ? Colors.green
          : Theme.of(context).colorScheme.error,
    );
  }
}
