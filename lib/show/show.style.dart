import 'package:flutter/material.dart';
import 'package:mix/mix.dart';

import '../providers/artnet.dart';

StyleMix getShowCardStyle() {
  return StyleMix(
    paddingSymmetric(horizontal: 16, vertical: 8),
    margin(8),
    rounded(16),
    backgroundColor(const Color.fromARGB(255, 0, 0, 0)),
    shadow(
      color: Colors.white12,
      blurRadius: 10,
      spreadRadius: 0,
    ),
    icon(size: 24, color: Colors.white),
  );
}

StyleMix getChipStatusStyle(ArtnetState artnetState) {
  final base = StyleMix(
    paddingSymmetric(horizontal: 10, vertical: 10),
    marginSymmetric(horizontal: 4),
    rounded(64),
    border(color: Colors.white),
  );

  return base.merge(getStatusStyle(artnetState));
}

StyleMix getStatusStyle(ArtnetState artnetState) {
  return StyleMix(
    backgroundColor(getStatusColor(artnetState)),
  );
}

StyleMix getLightStyle() {
  return StyleMix(
    width(double.infinity),
    height(double.infinity),
  );
}

Color getStatusColor(ArtnetState artnetState) {
  return artnetState.isReady
      ? artnetState.lastValidPacketTime == null
          ? Colors.amber.shade700
          : Colors.green
      : Colors.red;
}
