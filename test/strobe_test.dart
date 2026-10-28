import 'dart:async';

import 'package:chromapulse/strobe.dart';
import 'package:flutter_test/flutter_test.dart';

const fastest = Duration(microseconds: 166667);

void main() {
  group('strobeHalfPeriod', () {
    test('0 means no strobe', () {
      expect(strobeHalfPeriod(0), isNull);
    });

    test('1 to 255 maps to 0.5 to 3 Hz', () {
      expect(strobeHalfPeriod(1), const Duration(seconds: 1));
      expect(strobeHalfPeriod(255), fastest);
    });

    test('never flashes faster than 3 Hz', () {
      for (var value = 1; value <= 255; value++) {
        expect(strobeHalfPeriod(value)!, greaterThanOrEqualTo(fastest));
      }
    });
  });

  group('Strobe', () {
    testWidgets('alternates at the rate of the value', (tester) async {
      final changes = <bool>[];
      late final Strobe strobe;
      strobe = Strobe(() => changes.add(strobe.lit));

      strobe.set(255);
      await tester.pump(fastest * 4);
      expect(changes, [false, true, false, true]);
      strobe.cancel();
    });

    testWidgets('255 flashes 3 times a second', (tester) async {
      var flashes = 0;
      late final Strobe strobe;
      strobe = Strobe(() => flashes += strobe.lit ? 0 : 1);

      strobe.set(255);
      await tester.pump(const Duration(seconds: 10));
      expect(flashes, 30);
      strobe.cancel();
    });

    testWidgets('0 and 255 chatter never flashes faster than 3 Hz', (
      tester,
    ) async {
      final changes = <bool>[];
      late final Strobe strobe;
      strobe = Strobe(() => changes.add(strobe.lit));

      strobe.set(255);
      await tester.pump(fastest + const Duration(milliseconds: 5));
      expect(changes, [false]);

      for (var i = 0; i < 11; i++) {
        strobe.set(i.isEven ? 0 : 255);
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(changes, [false]);

      for (var i = 0; i < 40; i++) {
        strobe.set(i.isEven ? 0 : 255);
        await tester.pump(const Duration(milliseconds: 10));
      }
      strobe.set(0);
      await tester.pump(fastest * 2);
      expect(changes, [false, true]);
      expect(strobe.lit, true);
    });
  });

  group('LatestSwitch', () {
    test('drops requests made during a slow call', () async {
      final calls = <bool>[];
      var pending = Completer<void>();
      final torch = LatestSwitch((on) {
        calls.add(on);
        return pending.future;
      });

      for (var i = 0; i < 100; i++) {
        torch.set(i.isEven);
      }
      expect(calls, [true]);

      final first = pending;
      pending = Completer<void>();
      first.complete();
      await Future<void>.delayed(Duration.zero);
      expect(calls, [true, false]);

      pending.complete();
      await Future<void>.delayed(Duration.zero);
      expect(calls, [true, false]);
    });

    test('skips the call when the target is already applied', () async {
      final calls = <bool>[];
      final torch = LatestSwitch((on) async => calls.add(on));

      torch.set(true);
      await Future<void>.delayed(Duration.zero);
      torch.set(true);
      await Future<void>.delayed(Duration.zero);
      expect(calls, [true]);
    });

    test('retries a failed call on the next request', () async {
      final calls = <bool>[];
      var busy = true;
      final torch = LatestSwitch((on) async {
        calls.add(on);
        if (busy) throw Exception('camera busy');
      });

      torch.set(true);
      await Future<void>.delayed(Duration.zero);
      expect(calls, [true]);

      busy = false;
      torch.set(true);
      await Future<void>.delayed(Duration.zero);
      torch.set(true);
      await Future<void>.delayed(Duration.zero);
      expect(calls, [true, true]);
    });

    test('reports a failed call', () async {
      final failed = <bool>[];
      final torch = LatestSwitch(
        (on) async => throw Exception('camera busy'),
        onFailed: failed.add,
      );

      torch.set(true);
      await Future<void>.delayed(Duration.zero);
      expect(failed, [true]);
    });
  });
}
