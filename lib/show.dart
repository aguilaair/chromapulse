import 'dart:async';

import 'package:chromapulse/dimmer.dart';
import 'package:chromapulse/providers/artnet.dart';
import 'package:chromapulse/providers/providers.dart';
import 'package:chromapulse/providers/settings.dart';
import 'package:chromapulse/strobe.dart';
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

class _ShowPageState extends ConsumerState<ShowPage>
    with SingleTickerProviderStateMixin {
  static const _brightnessInterval = Duration(milliseconds: 50);

  bool _torchAvailable = false;
  bool _torchOn = false;
  bool _signalLost = false;
  Timer? _signalTimer;
  late final _torch = LatestSwitch(
    (on) => on ? TorchLight.enableTorch() : TorchLight.disableTorch(),
    // Camera busy or torch unavailable, retry on the next DMX change
    onFailed: (on) {
      if (_torchOn == on && mounted) setState(() => _torchOn = !on);
    },
  );
  late final _strobe = Strobe(() {
    if (!mounted) return;
    setState(() {});
    _setTorch(_torchOn);
  });

  late final SettingsState _settings;
  late final AnimationController _fade;
  late LightLevels _from;
  late LightLevels _to;
  double? _sentBrightness;
  DateTime _sentAt = DateTime(0);

  LightLevels get _shown =>
      LightLevels.lerp(_from, _to, _fade.value).output(_settings);

  @override
  void initState() {
    super.initState();
    _checkTorch();
    _settings = ref.read(settingsStateProvider);
    _fade = AnimationController(vsync: this)
      ..addListener(() => _pushBrightness(force: _fade.isCompleted));
    _from = _to = _levels(ref.read(artnetStateProvider));
    _pushBrightness(force: true);
    ref.listenManual(artnetStateProvider, (_, dmx) => _fadeTo(_levels(dmx)));
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
    final hold = settings.signalLossAction == SignalLossAction.hold;
    setState(() {
      _signalLost = lost;
      if (lost) {
        // A lost signal never strobes, even when the look is held.
        _strobe.set(0);
        if (!hold) _setTorch(false);
        return;
      }
      // The packet's channel values are written just after its timestamp.
      scheduleMicrotask(() {
        if (!mounted) return;
        final artnet = ref.read(artnetStateProvider);
        // Recovery is instant: jump to the packet's look instead of fading in
        // from whatever was showing before the loss.
        setState(() => _snap(_levels(artnet)));
        if (settings.useStrobeChannel && artnet.strobe.value >= 0) {
          _strobe.set(artnet.strobe.value);
        }
        final torch = artnet.torch.value;
        if (!hold && settings.useTorchChannel && torch >= 0) {
          setState(() => _setTorch(torch >= 128));
        }
      });
    });
  }

  LightLevels _levels(ArtnetState dmx) =>
      LightLevels.fromDmx(dmx, brightness: _settings.use4Channels);

  void _fadeTo(LightLevels target) {
    if (target == _to) return;
    final fadeTimeMs = _settings.fadeTimeMs;
    if (fadeTimeMs == 0) {
      _snap(target);
      return;
    }
    _from = LightLevels.lerp(_from, _to, _fade.value);
    _to = target;
    _fade.duration = Duration(milliseconds: fadeTimeMs);
    _fade.forward(from: 0);
  }

  void _snap(LightLevels target) {
    _fade.stop();
    _from = _to = target;
    _pushBrightness(force: true);
  }

  /// The platform call is slow, so fades update it at most every
  /// [_brightnessInterval]; [force] lands the final value.
  void _pushBrightness({bool force = false}) {
    final level = _shown.brightness;
    if (level == null || level == _sentBrightness) return;
    final now = DateTime.now();
    if (!force && now.difference(_sentAt) < _brightnessInterval) return;
    _sentBrightness = level;
    _sentAt = now;
    ScreenBrightness().setApplicationScreenBrightness(level);
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

  void _setTorch(bool on) {
    if (!_torchAvailable) return;
    _torchOn = on;
    _torch.set(_torchOn && _strobe.lit);
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
    _fade.dispose();
    super.dispose();
  }

  void cleanUp() {
    _strobe.cancel();
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

  @override
  Widget build(BuildContext context) {
    artnetState = ref.watch(artnetStateProvider);
    final settings = ref.read(settingsStateProvider);
    final is4Channel = settings.use4Channels;
    final useTorchChannel = settings.useTorchChannel;
    final useStrobeChannel = settings.useStrobeChannel;
    final zones = [
      for (var z = 0; z < settings.zoneCount; z++)
        z < (artnetState?.zones.length ?? 0)
            ? artnetState!.zones[z]
            : RgbZone.off,
    ];

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
    ref.listen(artnetStateProvider.select((s) => s.strobe.value), (
      previous,
      value,
    ) {
      if (useStrobeChannel && value >= 0 && !_signalLost) {
        _strobe.set(value);
      }
    });
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

    // The strobe gates every zone together; loss looks cover the whole screen
    Color shownColor(Color live) {
      final strobed = _strobe.lit ? live : Colors.black;
      return !_signalLost
          ? strobed
          : switch (settings.signalLossAction) {
              SignalLossAction.hold => strobed,
              SignalLossAction.blackout ||
              SignalLossAction.fade => Colors.black,
              SignalLossAction.colour => Color(
                0xFF000000 | settings.signalLossColor,
              ),
            };
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
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _fade,
                builder: (context, _) {
                  final shown = _shown.zones;
                  return ZoneCanvas(
                    colors: [
                      for (var z = 0; z < settings.zoneCount; z++)
                        shownColor(z < shown.length ? shown[z] : Colors.black),
                    ],
                    layout: settings.zoneLayout,
                    duration:
                        _signalLost &&
                            settings.signalLossAction == SignalLossAction.fade
                        ? const Duration(seconds: 2)
                        : Duration.zero,
                  );
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Last Packet: $packetTimeAgo"
                                  "${_signalLost ? " (signal lost)" : ""}",
                                ),
                                Wrap(
                                  children: [
                                    if (zones.length == 1) ...[
                                      Text(
                                        "R: ${zones.first.red}",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall!
                                            .copyWith(color: Colors.red),
                                      ),
                                      Text(
                                        " G: ${zones.first.green}",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall!
                                            .copyWith(color: Colors.green),
                                      ),
                                      Text(
                                        " B: ${zones.first.blue}",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall!
                                            .copyWith(color: Colors.blue),
                                      ),
                                    ] else
                                      for (final zone in zones)
                                        ZoneReadout(zone: zone),
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
                                    if (useStrobeChannel)
                                      Text(
                                        " S: ${artnetState?.strobe.value ?? 0}",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall!
                                            .copyWith(color: Colors.white),
                                      ),
                                  ],
                                ),
                              ],
                            ),
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

class ZoneCanvas extends StatelessWidget {
  const ZoneCanvas({
    super.key,
    required this.colors,
    required this.layout,
    this.duration = Duration.zero,
  });

  final List<Color> colors;
  final ZoneLayout layout;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: layout == ZoneLayout.rows ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final color in colors)
          Expanded(
            child: AnimatedContainer(duration: duration, color: color),
          ),
      ],
    );
  }
}

class ZoneReadout extends StatelessWidget {
  const ZoneReadout({super.key, required this.zone});

  final RgbZone zone;

  @override
  Widget build(BuildContext context) {
    final hex = [
      zone.red,
      zone.green,
      zone.blue,
    ].map((v) => v.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: zone.color,
              border: Border.all(color: Colors.white54),
            ),
          ),
          Text(" $hex", style: Theme.of(context).textTheme.bodySmall),
        ],
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
