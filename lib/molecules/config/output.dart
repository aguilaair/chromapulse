import 'package:chromapulse/dimmer.dart';
import 'package:chromapulse/providers/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/providers.dart';
import '../setting_edit_dialog.dart';

class OutputConfigurationTile extends HookConsumerWidget {
  const OutputConfigurationTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsStateProvider);
    final notifier = ref.read(settingsStateProvider.notifier);
    return ExpansionTile(
      title: const Text("Output"),
      children: [
        ListTile(
          title: const Text("Dimmer Curve"),
          subtitle: Text(
            settings.use4Channels || settings.curveRgb
                ? "Square law gives finer control at low brightness."
                : "Needs 4-channel mode or Apply Curve to Colour.",
          ),
          trailing: DropdownButton<DimmerCurve>(
            value: settings.dimmerCurve,
            onChanged: (value) {
              if (value != null) notifier.setDimmerCurve(value);
            },
            items: [
              for (final curve in DimmerCurve.values)
                DropdownMenuItem(value: curve, child: Text(curve.label)),
            ],
          ),
        ),
        ListTile(
          title: const Text("Apply Curve to Colour"),
          subtitle: const Text(
            "Also apply the curve to red, green and blue. "
            "Mid colours get much darker and mixed colours shift.",
          ),
          trailing: Switch(
            value: settings.curveRgb,
            onChanged: notifier.setCurveRgb,
          ),
        ),
        ListTile(
          title: const Text("Fade Time"),
          subtitle: Text(
            settings.fadeTimeMs == 0 ? "Instant" : "${settings.fadeTimeMs} ms",
          ),
          trailing: IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => SettingEditDialog(
                  title: "Fade Time (ms)",
                  onSave: (setting) {
                    final fadeTimeMs = int.tryParse(setting);
                    if (fadeTimeMs == null ||
                        fadeTimeMs < 0 ||
                        fadeTimeMs > SettingsState.maxFadeTimeMs) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Invalid fade time, enter "
                            "a number between 0 and ${SettingsState.maxFadeTimeMs}",
                          ),
                        ),
                      );
                      return;
                    }
                    notifier.setFadeTimeMs(fadeTimeMs);
                  },
                  initialValue: settings.fadeTimeMs.toString(),
                ),
              );
            },
            icon: const Icon(CupertinoIcons.pen),
          ),
        ),
      ],
    );
  }
}
