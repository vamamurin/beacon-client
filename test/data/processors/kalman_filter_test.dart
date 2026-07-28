// Destination: test/data/processors/kalman_filter_test.dart
// Run with: flutter test test/data/processors/kalman_filter_test.dart
//
// Pins the property the old filter did not have: responsiveness measured in
// WALL-CLOCK time rather than in packet count.
//
// The bug being locked out: process noise used to be added once per update(),
// so the filter's time constant was ~23 SAMPLES. At the 10 Hz iBeacon rate that
// is ~2.3 s (intended); when Android throttles scan callbacks to ~1 Hz the very
// same filter takes ~23 s to notice the visitor moved. Since ZoneArbiter's
// engage/release gates are computed from this estimate, the whole positioning
// layer silently changed behaviour with power state and device.

import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/data/processors/kalman_filter.dart';

/// Feeds [measurement] repeatedly for [over] of virtual time, one sample every
/// [every]. Returns the final estimate.
double converge(
  KalmanFilter f,
  double measurement, {
  required Duration every,
  required Duration over,
}) {
  var elapsed = Duration.zero;
  var out = 0.0;
  while (elapsed < over) {
    out = f.update(measurement, elapsed: every);
    elapsed += every;
  }
  return out;
}

void main() {
  const dense = Duration(milliseconds: 100); // 10 Hz — the nominal rate
  const sparse = Duration(seconds: 1); //        1 Hz — Android throttling us

  group('backward compatibility', () {
    test('at the nominal rate, elapsed changes nothing vs the old fixed step',
        () {
      // Every field-tuned kalmanProcessNoise in every shipped manifest was
      // calibrated under the old per-update semantics at ~10 Hz. Those values
      // must keep meaning exactly what they meant.
      final timed = KalmanFilter();
      final untimed = KalmanFilter();

      for (var i = 0; i < 50; i++) {
        final m = -70.0 + (i.isEven ? 2 : -2);
        expect(
          timed.update(m, elapsed: dense),
          closeTo(untimed.update(m), 1e-12),
        );
      }
    });

    test('omitting elapsed is exactly one nominal step', () {
      final a = KalmanFilter();
      final b = KalmanFilter();
      a.update(-60);
      b.update(-60);
      expect(a.update(-80, elapsed: dense), closeTo(b.update(-80), 1e-12));
    });
  });

  group('a starved packet stream is compensated, not ignored', () {
    // ⚠ SCOPE — read before strengthening these bounds.
    //
    // Time-scaling the process noise does NOT make 1 Hz behave like 10 Hz, and
    // it must not be expected to: three measurements genuinely carry less
    // information than thirty, and a Kalman filter that pretended otherwise
    // would be lying about its own uncertainty. What the fix removes is the
    // UNIT ERROR — process noise growing per packet instead of per second — so
    // a sparse stream now earns a larger gain per sample instead of crawling.
    //
    // Measured, 3 s after a 30 dB step (fraction of the step covered):
    //     10 Hz   old 74.4%   new 74.4%   (identical — the calibration rate)
    //      5 Hz   old 49.7%   new 56.8%
    //      2 Hz   old 24.2%   new 33.7%
    //      1 Hz   old 13.0%   new 20.8%
    //
    // Closing the REMAINING gap is a tuning decision, not a code one: it needs
    // a larger kalmanProcessNoise in the manifest (~0.2 for parity at 1 Hz).
    // That trade-off — responsiveness against jitter — belongs to the site
    // survey, and it is only expressible at all because the unit is now defined.

    double progress(KalmanFilter f, Duration every) {
      converge(f, -80, every: every, over: const Duration(seconds: 20));
      final after = converge(f, -50, every: every, over: const Duration(seconds: 3));
      return (after + 80) / 30; // fraction of the 30 dB step covered
    }

    test('the sparse stream covers materially more ground than it used to', () {
      // Reproduces the OLD semantics by holding the step count at 1 regardless
      // of real time — i.e. process noise per packet.
      final old = KalmanFilter();
      converge(old, -80, every: dense, over: const Duration(seconds: 20));
      var oldOut = 0.0;
      for (var i = 0; i < 3; i++) {
        oldOut = old.update(-50, elapsed: dense); // 3 packets, 1 step each
      }
      final oldProgress = (oldOut + 80) / 30;

      final now = progress(KalmanFilter(), sparse); // 3 packets, 10 steps each

      expect(now, greaterThan(oldProgress * 1.4),
          reason: 'a 1 Hz stream must gain a lot on the per-packet formulation');
    });

    test('progress degrades gracefully with rate instead of collapsing', () {
      final p10 = progress(KalmanFilter(), dense);
      final p2 = progress(KalmanFilter(), const Duration(milliseconds: 500));
      final p1 = progress(KalmanFilter(), sparse);

      // Monotone in rate — more packets is still better, as it must be.
      expect(p10, greaterThan(p2));
      expect(p2, greaterThan(p1));

      // But the floor holds: even the starved stream commits to a fifth of the
      // move within 3 s, rather than the ~13% the per-packet version managed.
      expect(p1, greaterThan(0.18));
    });

    test('silence widens uncertainty, so the next packet counts for more', () {
      final steady = KalmanFilter();
      converge(steady, -70, every: dense, over: const Duration(seconds: 20));
      final pAfterSteady = steady.errorCovariance;

      // Same filter state, but now the beacon goes quiet for 5 s.
      final gapped = KalmanFilter();
      converge(gapped, -70, every: dense, over: const Duration(seconds: 20));
      gapped.update(-70, elapsed: const Duration(seconds: 5));

      // A long gap must leave the estimate LESS certain than a dense stream
      // does, which is what makes the following measurement carry more weight.
      expect(gapped.errorCovariance, greaterThan(pAfterSteady));
    });
  });

  group('hostile time', () {
    test('a negative delta (out-of-order packet) cannot corrupt covariance', () {
      final f = KalmanFilter();
      converge(f, -70, every: dense, over: const Duration(seconds: 5));
      final before = f.errorCovariance;

      f.update(-70, elapsed: const Duration(milliseconds: -500));

      expect(f.errorCovariance, lessThanOrEqualTo(before));
      expect(f.errorCovariance, greaterThan(0));
      expect(f.hasData, isTrue);
    });

    test('an absurd delta is capped instead of exploding the estimate', () {
      final capped = KalmanFilter();
      final absurd = KalmanFilter();
      converge(capped, -70, every: dense, over: const Duration(seconds: 5));
      converge(absurd, -70, every: dense, over: const Duration(seconds: 5));

      capped.update(-70, elapsed: KalmanFilter.maxStep);
      absurd.update(-70, elapsed: const Duration(days: 1));

      expect(absurd.errorCovariance, closeTo(capped.errorCovariance, 1e-12));
    });

    test('the very first measurement is adopted whatever the delta says', () {
      final f = KalmanFilter();
      expect(f.hasData, isFalse);
      expect(f.update(-63, elapsed: const Duration(hours: 9)), -63);
      expect(f.hasData, isTrue);
    });
  });
}
