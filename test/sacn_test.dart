import 'dart:typed_data';

import 'package:chromapulse/providers/sacn.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List e131({
  int universe = 1,
  int priority = 100,
  int options = 0,
  int startCode = 0,
  List<int> dmx = const [255, 128, 0],
  int cidByte = 1,
}) {
  final b = ByteData(126 + dmx.length);
  b.setUint16(0, 0x0010);
  'ASC-E1.17'.codeUnits.asMap().forEach((i, c) => b.setUint8(4 + i, c));
  b.setUint16(16, 0x7000 | (b.lengthInBytes - 16));
  b.setUint32(18, 0x00000004);
  for (var i = 0; i < 16; i++) {
    b.setUint8(22 + i, cidByte);
  }
  b.setUint16(38, 0x7000 | (b.lengthInBytes - 38));
  b.setUint32(40, 0x00000002);
  b.setUint8(108, priority);
  b.setUint8(112, options);
  b.setUint16(113, universe);
  b.setUint16(115, 0x7000 | (b.lengthInBytes - 115));
  b.setUint8(117, 0x02);
  b.setUint8(118, 0xa1);
  b.setUint16(121, 1);
  b.setUint16(123, dmx.length + 1);
  b.setUint8(125, startCode);
  dmx.asMap().forEach((i, v) => b.setUint8(126 + i, v));
  return b.buffer.asUint8List();
}

void main() {
  group('SacnPacket.parse', () {
    test('reads universe, priority and DMX slots', () {
      final packet = SacnPacket.parse(e131(universe: 258, priority: 150))!;
      expect(packet.universe, 258);
      expect(packet.priority, 150);
      expect(packet.dmx, [255, 128, 0]);
      expect(packet.cid, '01' * 16);
      expect(packet.preview, false);
      expect(packet.streamTerminated, false);
    });

    test('reads preview and stream terminated options', () {
      expect(SacnPacket.parse(e131(options: 0x80))!.preview, true);
      expect(SacnPacket.parse(e131(options: 0x40))!.streamTerminated, true);
    });

    test('rejects non-zero start codes', () {
      expect(SacnPacket.parse(e131(startCode: 0xdd)), null);
    });

    test('rejects Art-Net and truncated packets', () {
      final artnet = Uint8List(530)..setAll(0, 'Art-Net'.codeUnits);
      expect(SacnPacket.parse(artnet), null);
      final full = e131();
      expect(SacnPacket.parse(full.sublist(0, full.length - 1)), null);
    });

    test('rejects universe 0', () {
      expect(SacnPacket.parse(e131(universe: 0)), null);
    });
  });

  test('multicast group splits the universe into two octets', () {
    expect(sacnMulticastAddress(1).address, '239.255.0.1');
    expect(sacnMulticastAddress(258).address, '239.255.1.2');
  });

  group('SacnSourceArbiter', () {
    final t0 = DateTime(2026);

    test('follows the highest priority source', () {
      final arbiter = SacnSourceArbiter();
      final low = SacnPacket.parse(e131(priority: 50, cidByte: 1))!;
      final high = SacnPacket.parse(e131(priority: 150, cidByte: 2))!;
      expect(arbiter.accept(low, t0), true);
      expect(arbiter.accept(high, t0), true);
      expect(arbiter.accept(low, t0), false);
    });

    test('falls back when the high priority source times out', () {
      final arbiter = SacnSourceArbiter();
      final low = SacnPacket.parse(e131(priority: 50, cidByte: 1))!;
      final high = SacnPacket.parse(e131(priority: 150, cidByte: 2))!;
      arbiter.accept(high, t0);
      expect(arbiter.accept(low, t0.add(const Duration(seconds: 1))), false);
      expect(arbiter.accept(low, t0.add(const Duration(seconds: 3))), true);
    });

    test('drops a source as soon as it terminates its stream', () {
      final arbiter = SacnSourceArbiter();
      final low = SacnPacket.parse(e131(priority: 50, cidByte: 1))!;
      final high = SacnPacket.parse(e131(priority: 150, cidByte: 2))!;
      final bye = SacnPacket.parse(
        e131(priority: 150, cidByte: 2, options: 0x40),
      )!;
      arbiter.accept(high, t0);
      expect(arbiter.accept(bye, t0), false);
      expect(arbiter.accept(low, t0), true);
    });
  });
}
