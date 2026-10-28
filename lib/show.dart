import 'dart:async';

import 'package:chromapulse/providers/artnet.dart';
import 'package:chromapulse/providers/providers.dart';
import 'package:chromapulse/providers/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:torch_light/torch_light.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ShowPage extends StatefulHookConsumerWidget {
  const ShowPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ShowPageState();
}

class _ShowPageState extends ConsumerState<ShowPage> {
  bool _torchAvailable = false;
  bool _torchOn = false;
  Future<void> _torchQueue = Future.value();
  bool _signalLost = false;
  Timer? _signalTimer;

  @override
  void initState() {
    super.initState();
    _checkTorch();
    _signalTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _checkSignal(),
    );
  }

  void _checkSignal() {
    if (!mounted) return;
    final settings = ref.read(settingsStateProvider);
    final artnet = ref.read(artnetStateProvider);
    final lost =
        artnet.streamTerminated ||
        settings.isSignalLost(artnet.lastValidPacketTime, DateTime.now());
    if (lost == _signalLost) return;
    setState(() {
      _signalLost = lost;
      if (settings.signalLossAction == SignalLossAction.hold) return;
      if (lost) {
        _setTorch(false);
      } else if (settings.useTorchChannel) {
        // The packet's channel values are written just after its timestamp.
        scheduleMicrotask(() {
          final torch = ref.read(artnetStateProvider).torch.value;
          if (mounted && torch >= 0) setState(() => _setTorch(torch >= 128));
        });
      }
    });
  }

  Future<void> _checkTorch() async {
    bool available;
    try {
      available = await TorchLight.isTorchAvailable();
    } catch (e) {
      // Not implemented on desktop/web
      available = false;
    }
    if (mounted) setState(() => _torchAvailable = available);
  }

  /// Serialises torch calls so fast DMX chases can't race each other.
  void _setTorch(bool on) {
    if (!_torchAvailable || on == _torchOn) return;
    _torchOn = on;
    _torchQueue = _torchQueue.then((_) async {
      try {
        on ? await TorchLight.enableTorch() : await TorchLight.disableTorch();
      } catch (e) {
        // Camera busy or torch unavailable, retry on the next DMX change
        if (_torchOn == on && mounted) setState(() => _torchOn = !on);
      }
    });
  }

  // Show material banner on page load
  @override
  void didChangeDependencies() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    WakelockPlus.enable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _signalTimer?.cancel();
    cleanUp();
    super.dispose();
  }

  void cleanUp() {
    _setTorch(false);
    ScreenBrightness().resetApplicationScreenBrightness();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.disable();
  }

  late ArtnetState? artnetState;
  bool _isBannerVisible = false;
  int lastBrightness = -1;

  @override
  Widget build(BuildContext context) {
    artnetState = ref.watch(artnetStateProvider);
    final settings = ref.read(settingsStateProvider);
    final is4Channel = settings.use4Channels;
    final useTorchChannel = settings.useTorchChannel;

    // DMX drives the torch; any change on the channel overrides manual taps
    ref.listen(artnetStateProvider.select((s) => s.torch.value), (
      previous,
      value,
    ) {
      if (useTorchChannel && value >= 0) {
        setState(() => _setTorch(value >= 128));
      }
    });
    ref.listen(
      artnetStateProvider.select(
        (s) => (s.lastValidPacketTime, s.streamTerminated),
      ),
      (_, _) => _checkSignal(),
    );
    late String packetTimeAgo;
    Duration? packetTimeDifference;
    if (artnetState?.lastValidPacketTime != null) {
      // Difference between now and last packet time
      packetTimeDifference = DateTime.now().difference(
        artnetState!.lastValidPacketTime ?? DateTime.now(),
      );
      // seconds since last packet
      final seconds = packetTimeDifference.inSeconds;
      packetTimeAgo = "${seconds}s ago";
    } else {
      packetTimeAgo = "Never";
    }

    final liveColor = Color.fromARGB(
      255,
      artnetState?.red.value ?? 0,
      artnetState?.green.value ?? 0,
      artnetState?.blue.value ?? 0,
    );

    if (is4Channel) {
      if (lastBrightness == -1 && artnetState?.brightness.value != null) {
        lastBrightness = artnetState?.brightness.value ?? 0;
        ScreenBrightness().setApplicationScreenBrightness(lastBrightness / 255);
      } else if (artnetState?.brightness.value != null &&
          lastBrightness != (artnetState!.brightness.value)) {
        lastBrightness = artnetState?.brightness.value ?? 0;
        ScreenBrightness().setApplicationScreenBrightness(lastBrightness / 255);
      }
    }
    return Scaffold(
      body: GestureDetector(
        onDoubleTap: () {
          setState(() {
            _isBannerVisible = true;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Positioned(
              child: AnimatedContainer(
                width: double.infinity,
                height: double.infinity,
                duration:
                    _signalLost &&
                        settings.signalLossAction == SignalLossAction.fade
                    ? const Duration(seconds: 2)
                    : Duration.zero,
                color: !_signalLost
                    ? liveColor
                    : switch (settings.signalLossAction) {
                        SignalLossAction.hold => liveColor,
                        SignalLossAction.blackout ||
                        SignalLossAction.fade => Colors.black,
                        SignalLossAction.colour => Color(
                          0xFF000000 | settings.signalLossColor,
                        ),
                      },
              ),
            ),
            if ((packetTimeDifference?.inSeconds ?? 11) > 10)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  color: getStatusColor(context, artnetState!),
                  backgroundColor: Colors.transparent,
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              bottom: _isBannerVisible ? 20 : -200,
              right: 0,
              left: 0,
              child: Card(
                shadowColor: Colors.white.withValues(alpha: 0.2),
                elevation: 10,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            settings.deviceName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const StatusBadge(),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Last Packet: $packetTimeAgo"
                                "${_signalLost ? " (signal lost)" : ""}",
                              ),
                              Row(
                                children: [
                                  Text(
                                    "R: ${artnetState?.red.value ?? 0}",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(color: Colors.red),
                                  ),
                                  Text(
                                    " G: ${artnetState?.green.value ?? 0}",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(color: Colors.green),
                                  ),
                                  Text(
                                    " B: ${artnetState?.blue.value ?? 0}",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(color: Colors.blue),
                                  ),
                                  if (is4Channel)
                                    Text(
                                      " Br: ${artnetState?.brightness.value ?? 0}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(color: Colors.white),
                                    ),
                                  if (useTorchChannel)
                                    Text(
                                      " T: ${artnetState?.torch.value ?? 0}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(color: Colors.amber),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (_torchAvailable)
                                IconButton(
                                  onPressed: () {
                                    setState(() => _setTorch(!_torchOn));
                                  },
                                  tooltip: "Torch",
                                  isSelected: _torchOn,
                                  icon: const Icon(Icons.flashlight_off),
                                  selectedIcon: const Icon(Icons.flashlight_on),
                                ),
                              OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _isBannerVisible = false;
                                  });
                                },
                                child: const Text("Hide"),
                              ),
                              IconButton(
                                onPressed: () {
                                  cleanUp();
                                  Navigator.of(context).pop();
                                },
                                icon: const Icon(CupertinoIcons.settings),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusBadge extends HookConsumerWidget {
  const StatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artnetState = ref.watch(artnetStateProvider);
    return Chip(
      label: Text(
        "Status: ${artnetState.isReady
            ? artnetState.lastValidPacketTime != null
                  ? "Recieveing"
                  : "Ready (Waiting)"
            : "Not Ready"}",
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: Colors.white),
      ),
      backgroundColor: getStatusColor(context, artnetState),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: const BorderSide(color: Colors.white, width: 1),
    );
  }
}

Color getStatusColor(BuildContext context, ArtnetState artnetState) {
  return artnetState.isReady
      ? artnetState.lastValidPacketTime == null
            ? Colors.amber.shade700
            : Colors.green
      : Colors.red;
}
