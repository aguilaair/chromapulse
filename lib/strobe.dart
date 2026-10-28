import 'dart:async';

/// Slowest strobe rate, at DMX value 1.
const double minStrobeHz = 0.5;

/// Fastest strobe rate, at DMX value 255. WCAG 2.3.1 and Ofcom allow at most
/// three flashes per second to limit the risk to people with photosensitive
/// epilepsy, and a full-screen phone held near an audience is that case.
const double maxStrobeHz = 3;

/// Time the screen stays lit, or dark, for a strobe DMX [value].
///
/// Returns null at 0, which means no strobe.
Duration? strobeHalfPeriod(int value) {
  if (value <= 0) return null;
  final hz =
      minStrobeHz +
      (maxStrobeHz - minStrobeHz) * (value.clamp(1, 255) - 1) / 254;
  return Duration(microseconds: (500000 / hz).round());
}

/// Alternates between lit and dark at the rate a strobe DMX value asks for.
///
/// Every change of state waits out a full half period, including the return
/// to lit when the value drops to 0. A controller that flips the channel
/// between 0 and 255 therefore can't flash the screen faster than the cap.
class Strobe {
  Strobe(this._onChange);

  final void Function() _onChange;
  int _value = 0;
  bool _lit = true;
  Timer? _timer;

  bool get lit => _lit;

  void set(int value) {
    _value = value;
    final halfPeriod = strobeHalfPeriod(value);
    if (halfPeriod != null) {
      _timer ??= Timer(halfPeriod, _toggle);
    } else if (_lit) {
      cancel();
    }
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void _toggle() {
    final halfPeriod = strobeHalfPeriod(_value);
    _lit = halfPeriod == null || !_lit;
    _timer = halfPeriod == null ? null : Timer(halfPeriod, _toggle);
    _onChange();
  }
}

/// Drives an on/off output whose calls are slow, such as the torch.
///
/// At most one call runs at a time. Requests that arrive during a call only
/// update the target, so a fast strobe never builds a queue of calls.
class LatestSwitch {
  LatestSwitch(this._apply, {this.onFailed});

  final Future<void> Function(bool on) _apply;
  final void Function(bool on)? onFailed;
  bool _target = false;
  bool _applied = false;
  bool _busy = false;

  void set(bool on) {
    _target = on;
    if (!_busy) _drain();
  }

  Future<void> _drain() async {
    _busy = true;
    while (_applied != _target) {
      final on = _target;
      try {
        await _apply(on);
        _applied = on;
      } catch (e) {
        onFailed?.call(on);
        break;
      }
    }
    _busy = false;
  }
}
