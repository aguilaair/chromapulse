import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const sacnPort = 5568;

/// Multicast group E1.31 senders use for [universe].
InternetAddress sacnMulticastAddress(int universe) =>
    InternetAddress('239.255.${universe >> 8}.${universe & 0xff}');

/// An E1.31 data packet carrying null start code DMX.
class SacnPacket {
  final String cid;
  final int priority;
  final int universe;
  final bool preview;
  final bool streamTerminated;
  final Uint8List dmx;

  SacnPacket({
    required this.cid,
    required this.priority,
    required this.universe,
    required this.preview,
    required this.streamTerminated,
    required this.dmx,
  });

  static const _acnId = [
    0x41, 0x53, 0x43, 0x2d, 0x45, 0x31, 0x2e, 0x31, 0x37, 0x00, 0x00, 0x00, //
  ];
  static const _headerLength = 126;

  /// Returns null for anything that is not a valid E1.31 DMX data packet.
  static SacnPacket? parse(Uint8List data) {
    if (data.length < _headerLength) return null;
    final view = ByteData.sublistView(data);
    if (view.getUint16(0) != 0x0010 || view.getUint16(2) != 0) return null;
    for (var i = 0; i < _acnId.length; i++) {
      if (data[4 + i] != _acnId[i]) return null;
    }
    if (view.getUint32(18) != 0x00000004) return null;
    if (view.getUint32(40) != 0x00000002) return null;
    if (data[117] != 0x02 || data[118] != 0xa1) return null;
    if (view.getUint16(119) != 0 || view.getUint16(121) != 1) return null;

    final valueCount = view.getUint16(123);
    if (valueCount < 1 || valueCount > 513) return null;
    if (data.length < _headerLength - 1 + valueCount) return null;
    if (data[125] != 0) return null;

    final universe = view.getUint16(113);
    if (universe < 1 || universe > 63999) return null;

    final options = data[112];
    return SacnPacket(
      cid: data
          .sublist(22, 38)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
      priority: data[108],
      universe: universe,
      preview: options & 0x80 != 0,
      streamTerminated: options & 0x40 != 0,
      dmx: Uint8List.sublistView(data, 126, _headerLength - 1 + valueCount),
    );
  }
}

/// Picks the highest priority source on a universe. Sources that share the
/// top priority are not merged; the latest packet wins.
class SacnSourceArbiter {
  static const sourceTimeout = Duration(milliseconds: 2500);

  final _sources = <String, ({int priority, DateTime lastSeen})>{};

  bool accept(SacnPacket packet, DateTime now) {
    _sources.removeWhere((_, s) => now.difference(s.lastSeen) > sourceTimeout);
    if (packet.streamTerminated) {
      _sources.remove(packet.cid);
      return false;
    }
    _sources[packet.cid] = (priority: packet.priority, lastSeen: now);
    return packet.priority >=
        _sources.values.map((s) => s.priority).reduce(max);
  }
}
