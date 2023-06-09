import 'package:chromapulse/providers/artnet.dart';
import 'package:chromapulse/providers/providers.dart';
import 'package:flutter/cupertino.dart';
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    Wakelock.enable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    cleanUp();
    super.dispose();
  }

  void cleanUp() {
    ScreenBrightness().resetScreenBrightness();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    Wakelock.disable();
  }

  late ArtnetState? artnetState;
  bool _isBannerVisible = false;
  int lastBrightness = -1;

  @override
  Widget build(BuildContext context) {
    artnetState = ref.watch(artnetStateProvider);
    final is4Channel = ref.read(settingsStateProvider).use4Channels;
    late String packetTimeAgo;
    Duration? packetTimeDifference;
    if (artnetState?.lastValidPacketTime != null) {
      // Difference between now and last packet time
      packetTimeDifference = DateTime.now()
          .difference(artnetState!.lastValidPacketTime ?? DateTime.now());
      // seconds since last packet
      final seconds = packetTimeDifference.inSeconds;
      packetTimeAgo = "${seconds}s ago";
    } else {
      packetTimeAgo = "Never";
    }

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
          setState(() {
            _isBannerVisible = true;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Positioned(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Color.fromARGB(
                  255,
                  artnetState?.red.value ?? 0,
                  artnetState?.green.value ?? 0,
                  artnetState?.blue.value ?? 0,
                ),
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
                  shadowColor: Colors.white.withOpacity(0.2),
                  elevation: 10,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Show Mode",
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
                                Text("Last Packet: $packetTimeAgo"),
                                Row(
                                  children: [
                                    Text(
                                      "R: ${artnetState?.red.value ?? 0}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(
                                            color: Colors.red,
                                          ),
                                    ),
                                    Text(
                                      " G: ${artnetState?.green.value ?? 0}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(
                                            color: Colors.green,
                                          ),
                                    ),
                                    Text(
                                      " B: ${artnetState?.blue.value ?? 0}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(
                                            color: Colors.blue,
                                          ),
                                    ),
                                    if (is4Channel)
                                      Text(
                                        " Br: ${artnetState?.brightness.value ?? 0}",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall!
                                            .copyWith(
                                              color: Colors.white,
                                            ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
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
                            )
                          ],
                        )
                      ],
                    ),
                  )),
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
          "Status: ${artnetState.isReady ? artnetState.lastValidPacketTime != null ? "Recieveing" : "Ready (Waiting)" : "Not Ready"}",
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Colors.white),
        ),
        backgroundColor: getStatusColor(context, artnetState),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: const BorderSide(
          color: Colors.white,
          width: 1,
        ));
  }
}

Color getStatusColor(BuildContext context, ArtnetState artnetState) {
  return artnetState.isReady
      ? artnetState.lastValidPacketTime == null
          ? Colors.amber.shade700
          : Colors.green
      : Colors.red;
}
