// Destination: test/session_controller_test.dart
// Run with: flutter test test/session_controller_test.dart
//
// Cập nhật theo chữ ký SessionController mới (P1-1):
//   • deskStable  -> Stream<bool> (tín hiệu dạng cạnh) thay cho PresenceTick.
//   • lastBeaconAt -> hàm poll `() => rig.lastBeaconAt`; test set biến
//     `rig.lastBeaconAt` rồi để sweep 1 Hz tự đọc, KHÔNG add vào stream nữa.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/domain/models/tour_session.dart';
import 'package:beacon_client/services/session_controller.dart';
import 'package:beacon_client/services/zone_presence_service.dart';

/// Records cleanup calls.
class _FakeAudioSink implements TourAudioSink {
  int stops = 0;
  int resets = 0;
  @override
  void stopAll() => stops++;
  @override
  void resetSessionMemory() => resets++;
}

/// Test rig: manual stream controllers + injected clock. Silence set short
/// (5 s) so silence tests don't need to simulate 30 virtual minutes.
class Rig {
  final zones = StreamController<ZoneEvent>.broadcast();
  final charging = StreamController<bool>.broadcast();

  /// Desk edges (was the `deskStable` field of the old PresenceTick).
  final desk = StreamController<bool>.broadcast();

  /// Polled freshness (was the `lastBeaconAt` field of PresenceTick). Tests
  /// set this, then let the sweep read it. Null = nothing heard yet.
  DateTime? lastBeaconAt;

  final audio = _FakeAudioSink();
  late final SessionController ctrl;
  final DateTime Function() now;

  Rig(this.now,
      {bool initialCharging = true,
      Duration? silence,
      Duration farewellHold = Duration.zero}) {
    ctrl = SessionController(
      zoneEvents: zones.stream,
      chargingChanges: charging.stream,
      initialCharging: initialCharging,
      deskStableChanges: desk.stream,
      lastBeaconAt: () => lastBeaconAt,
      audioSink: audio,
      sessionSilence: silence ?? const Duration(seconds: 5),
      startGraceTimeout: const Duration(seconds: 20),
      now: now,
      farewellHold: farewellHold,
    );
  }

  void dispose() {
    ctrl.dispose();
    zones.close();
    charging.close();
    desk.close();
  }
}

void main() {
  group('atDesk transitions', () {
    test('unplug wakes to gate', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed));
        rig.ctrl.start();
        rig.charging.add(false);
        async.flushMicrotasks();
        expect(rig.ctrl.current.phase, SessionPhase.gate);
        rig.dispose();
      });
    });

    test('zone events are ignored at the desk', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed));
        rig.ctrl.start();
        rig.zones.add(const EnteredZone(1));
        async.flushMicrotasks();
        expect(rig.ctrl.current.phase, SessionPhase.atDesk);
        rig.dispose();
      });
    });

    test('booting while NOT charging starts at the gate, not atDesk', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed),
            initialCharging: false);
        expect(rig.ctrl.current.phase, SessionPhase.gate);
        rig.dispose();
      });
    });
  });

  group('gate transitions', () {
    test('userStartedTour moves gate -> touring and opens grace', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed));
        rig.ctrl.start();
        rig.charging.add(false); // -> gate
        async.flushMicrotasks();
        rig.ctrl.userStartedTour();
        expect(rig.ctrl.current.phase, SessionPhase.touring);
        expect(rig.ctrl.current.inStartGrace, isTrue);
        rig.dispose();
      });
    });

    test('zone events ignored at gate (no auto-start)', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed));
        rig.ctrl.start();
        rig.charging.add(false);
        async.flushMicrotasks();
        rig.zones.add(const EnteredZone(1));
        async.flushMicrotasks();
        expect(rig.ctrl.current.phase, SessionPhase.gate);
        rig.dispose();
      });
    });

    test('re-plug returns gate -> atDesk', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed));
        rig.ctrl.start();
        rig.charging.add(false); // gate
        async.flushMicrotasks();
        rig.charging.add(true); // back on dock
        async.flushMicrotasks();
        expect(rig.ctrl.current.phase, SessionPhase.atDesk);
        rig.dispose();
      });
    });
  });

  group('touring end signals', () {
    /// Drives atDesk -> gate -> touring, past grace (via EnteredZone).
    SessionController toTouring(Rig rig, FakeAsync async) {
      rig.ctrl.start();
      rig.charging.add(false);
      async.flushMicrotasks();
      rig.ctrl.userStartedTour();
      rig.zones.add(const EnteredZone(1)); // closes grace
      async.flushMicrotasks();
      return rig.ctrl;
    }

    test('charging mid-tour ends instantly with reason=charging', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed));
        toTouring(rig, async);
        rig.charging.add(true);
        async.flushMicrotasks();
        expect(rig.ctrl.current.phase, SessionPhase.atDesk);
        expect(rig.ctrl.current.endReason, SessionEndReason.charging);
        // P1 fix: stopAll() now runs once at userStartedTour() (clearing
        // dock residue) and once here at _endSession() — two calls, not one.
        expect(rig.audio.stops, 2);
        expect(rig.audio.resets, 1);
        rig.dispose();
      });
    });

    test('deskStable after grace ends with reason=desk', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed));
        toTouring(rig, async); // grace already closed by EnteredZone
        rig.desk.add(true);
        async.flushMicrotasks();
        expect(rig.ctrl.current.phase, SessionPhase.atDesk);
        expect(rig.ctrl.current.endReason, SessionEndReason.desk);
        rig.dispose();
      });
    });

    test('deskStable DURING grace is ignored', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed));
        rig.ctrl.start();
        rig.charging.add(false);
        async.flushMicrotasks();
        rig.ctrl.userStartedTour(); // grace open, NO EnteredZone yet
        rig.desk.add(true);
        async.flushMicrotasks();
        expect(rig.ctrl.current.phase, SessionPhase.touring); // survived
        rig.dispose();
      });
    });

    test('grace times out after startGraceTimeout even without EnteredZone', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed));
        rig.ctrl.start();
        rig.charging.add(false);
        async.flushMicrotasks();
        rig.ctrl.userStartedTour();
        async.elapse(const Duration(seconds: 21)); // > 20 s grace cap
        async.flushMicrotasks();
        expect(rig.ctrl.current.inStartGrace, isFalse);
        rig.dispose();
      });
    });

    test('silence past sessionSilence ends with reason=silence', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed),
            silence: const Duration(seconds: 5));
        toTouring(rig, async);
        // Last beacon heard now; then go silent (stop updating lastBeaconAt).
        rig.lastBeaconAt = DateTime(2026).add(async.elapsed);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 6)); // > 5 s silence
        async.flushMicrotasks();
        expect(rig.ctrl.current.phase, SessionPhase.atDesk);
        expect(rig.ctrl.current.endReason, SessionEndReason.silence);
        rig.dispose();
      });
    });

    test('brief silence under threshold keeps touring', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed),
            silence: const Duration(seconds: 5));
        toTouring(rig, async);
        rig.lastBeaconAt = DateTime(2026).add(async.elapsed);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(rig.ctrl.current.phase, SessionPhase.touring);
        rig.dispose();
      });
    });

    test('a fresh beacon keeps the tour alive past the silence window', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed),
            silence: const Duration(seconds: 5));
        toTouring(rig, async);
        // Keep the poll fresh across a span longer than the silence window by
        // advancing lastBeaconAt each second — proves silence reads live time,
        // not a frozen presence value (the whole point of P1-1).
        rig.lastBeaconAt = DateTime(2026).add(async.elapsed);
        for (var i = 0; i < 8; i++) {
          async.elapse(const Duration(seconds: 1));
          rig.lastBeaconAt = DateTime(2026).add(async.elapsed);
        }
        async.flushMicrotasks();
        expect(rig.ctrl.current.phase, SessionPhase.touring);
        rig.dispose();
      });
    });

    test('staff manual end works', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed));
        toTouring(rig, async);
        rig.ctrl.staffEndSession();
        async.flushMicrotasks();
        expect(rig.ctrl.current.phase, SessionPhase.atDesk);
        expect(rig.ctrl.current.endReason, SessionEndReason.manual);
        rig.dispose();
      });
    });
  });

  group('priority / logging', () {
    test('charging preempts a later desk signal (reason stays charging)', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed));
        rig.ctrl.start();
        rig.charging.add(false);
        async.flushMicrotasks();
        rig.ctrl.userStartedTour();
        rig.zones.add(const EnteredZone(1));
        async.flushMicrotasks();

        rig.charging.add(true); // ends: charging
        async.flushMicrotasks();
        // A trailing desk edge must not re-end or change the reason.
        rig.desk.add(true);
        async.flushMicrotasks();
        expect(rig.ctrl.current.endReason, SessionEndReason.charging);
        // 1 from userStartedTour()'s dock-residue cleanup + 1 from the
        // charging-triggered _endSession(); the trailing desk edge below
        // must NOT add a third.
        expect(rig.audio.stops, 2);
        rig.dispose();
      });
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Chốt hợp đồng ghi trên SessionPhase.ending: nó là một CẠNH, luôn luôn.
  //
  // Ba lối kết thúc TỰ ĐỘNG đi qua đây, và cả ba đều xảy ra khi không ai đang
  // nhìn màn hình (máy trên dock / khách đứng ở quầy trả máy / máy bị bỏ quên),
  // nên không có gì cần vẽ. Lối kết thúc DO KHÁCH BẤM thì đi qua
  // SessionPhase.farewell — nhóm test ở cuối file.
  // ─────────────────────────────────────────────────────────────────────────
  group('SessionPhase.ending là một cạnh', () {
    test('it is never the settled phase a listener can observe at rest', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed));
        final seen = <SessionPhase>[];
        rig.ctrl.state.listen((s) => seen.add(s.phase));

        rig.ctrl.start();
        rig.charging.add(false);
        async.flushMicrotasks();
        rig.ctrl.userStartedTour();
        rig.zones.add(const EnteredZone(1));
        async.flushMicrotasks();

        rig.charging.add(true); // end the tour
        async.flushMicrotasks();

        // The edge WAS published (analytics depends on seeing it)...
        expect(seen, contains(SessionPhase.ending));
        // ...but it is immediately superseded, and never the resting phase.
        expect(rig.ctrl.current.phase, SessionPhase.atDesk);
        expect(seen.last, SessionPhase.atDesk);
        rig.dispose();
      });
    });

    test('atDesk follows it with no other phase in between', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed));
        final seen = <SessionPhase>[];
        rig.ctrl.state.listen((s) => seen.add(s.phase));

        rig.ctrl.start();
        rig.charging.add(false);
        async.flushMicrotasks();
        rig.ctrl.userStartedTour();
        rig.zones.add(const EnteredZone(1));
        async.flushMicrotasks();

        rig.desk.add(true); // end via the desk beacon this time
        async.flushMicrotasks();

        final i = seen.indexOf(SessionPhase.ending);
        expect(i, isNonNegative);
        expect(seen[i + 1], SessionPhase.atDesk,
            reason: 'nothing may be interleaved between the edge and the rest');
        rig.dispose();
      });
    });

    test('it carries the end reason — that is its whole job', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed));
        SessionEndReason? reasonOnEdge;
        rig.ctrl.state.listen((s) {
          if (s.phase == SessionPhase.ending) reasonOnEdge = s.endReason;
        });

        rig.ctrl.start();
        rig.charging.add(false);
        async.flushMicrotasks();
        rig.ctrl.userStartedTour();
        rig.zones.add(const EnteredZone(1));
        async.flushMicrotasks();

        rig.desk.add(true);
        async.flushMicrotasks();

        expect(reasonOnEdge, SessionEndReason.desk);
        rig.dispose();
      });
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // SessionPhase.farewell — lối kết thúc DO KHÁCH BẤM ở màn tổng kết.
  //
  // Khác `ending` ở đúng hai điểm, và cả hai đều được chốt ở đây:
  //   • là một TRẠNG THÁI THẬT, có cửa sổ thời gian để màn Cảm ơn sống trong đó;
  //   • cắm sạc thoát được — đó là thứ khiến hạn giữ 0 (vô hạn) an toàn.
  // Phần dọn dẹp thì phải giống hệt mọi lối kết thúc khác.
  // ─────────────────────────────────────────────────────────────────────────
  group('SessionPhase.farewell', () {
    /// Đưa rig tới đúng khoảnh khắc khách vừa bấm "Kết thúc chuyến đi".
    Rig farewellRig(FakeAsync async, {Duration hold = Duration.zero}) {
      final rig = Rig(() => DateTime(2026).add(async.elapsed), farewellHold: hold);
      rig.ctrl.start();
      rig.charging.add(false);
      async.flushMicrotasks();
      rig.ctrl.userStartedTour();
      rig.zones.add(const EnteredZone(1));
      async.flushMicrotasks();
      rig.ctrl.visitorEndedTour();
      async.flushMicrotasks();
      return rig;
    }

    test('là trạng thái quan sát được, mang theo lý do manual', () {
      fakeAsync((async) {
        final rig = farewellRig(async);
        expect(rig.ctrl.current.phase, SessionPhase.farewell);
        expect(rig.ctrl.current.endReason, SessionEndReason.manual);
        expect(rig.ctrl.current.isFarewell, isTrue);
        rig.dispose();
      });
    });

    // Đây là điều kiện để `farewell.autoReturnSeconds: 0` là một lựa chọn hợp
    // lệ chứ không phải một cách treo máy.
    test('hạn giữ 0 ⇒ giữ vô hạn, không tự trôi về atDesk', () {
      fakeAsync((async) {
        final rig = farewellRig(async);
        async.elapse(const Duration(hours: 2));
        expect(rig.ctrl.current.phase, SessionPhase.farewell);
        rig.dispose();
      });
    });

    test('hạn giữ khác 0 ⇒ tự về atDesk khi hết giờ', () {
      fakeAsync((async) {
        final rig = farewellRig(async, hold: const Duration(seconds: 10));
        async.elapse(const Duration(seconds: 9));
        expect(rig.ctrl.current.phase, SessionPhase.farewell);
        async.elapse(const Duration(seconds: 2));
        expect(rig.ctrl.current.phase, SessionPhase.atDesk);
        expect(rig.ctrl.current.endReason, SessionEndReason.manual);
        rig.dispose();
      });
    });

    test('khách bấm "Xong" ⇒ về atDesk ngay, không đợi hết hạn', () {
      fakeAsync((async) {
        final rig = farewellRig(async, hold: const Duration(minutes: 5));
        rig.ctrl.dismissFarewell();
        async.flushMicrotasks();
        expect(rig.ctrl.current.phase, SessionPhase.atDesk);
        rig.dispose();
      });
    });

    // ĐƯỜNG THOÁT VẬT LÝ: máy bị bỏ quên ở màn Cảm ơn vẫn sạch khi về tới quầy.
    test('cắm sạc ⇒ về atDesk kể cả khi đang giữ vô hạn', () {
      fakeAsync((async) {
        final rig = farewellRig(async);
        rig.charging.add(true);
        async.flushMicrotasks();
        expect(rig.ctrl.current.phase, SessionPhase.atDesk);
        rig.dispose();
      });
    });

    test('tiếng bị cắt NGAY, không đợi hết hạn giữ', () {
      fakeAsync((async) {
        final rig = farewellRig(async, hold: const Duration(minutes: 5));
        // 1 lần từ userStartedTour (dọn tàn dư trên dock) + 1 từ _endSession.
        // Khách không được nghe thuyết minh vọng qua màn cảm ơn.
        expect(rig.audio.stops, 2);
        rig.dispose();
      });
    });

    test('một chuyển động khác xen vào thắng; hẹn giờ tới muộn không giẫm lên',
        () {
      fakeAsync((async) {
        final rig = farewellRig(async, hold: const Duration(seconds: 3));
        rig.charging.add(true); // lên dock trước khi hết hạn
        async.flushMicrotasks();
        rig.charging.add(false); // khách kế tiếp rút máy ra ngay
        async.flushMicrotasks();
        expect(rig.ctrl.current.phase, SessionPhase.gate);

        async.elapse(const Duration(seconds: 5)); // hẹn giờ cũ bắn ở đây
        expect(rig.ctrl.current.phase, SessionPhase.gate);
        rig.dispose();
      });
    });

    test('dispose giữa cửa sổ giữ không phát thêm gì', () {
      fakeAsync((async) {
        final rig = farewellRig(async, hold: const Duration(seconds: 3));
        rig.dispose();
        async.elapse(const Duration(seconds: 10)); // không được ném
      });
    });

    // Nút trên notification: nhân viên thu máy về, không ai đứng trước màn hình.
    test('staffEndSession KHÔNG đi qua farewell', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed));
        rig.ctrl.start();
        rig.charging.add(false);
        async.flushMicrotasks();
        rig.ctrl.userStartedTour();
        rig.zones.add(const EnteredZone(1));
        async.flushMicrotasks();

        final seen = <SessionPhase>[];
        rig.ctrl.state.listen((s) => seen.add(s.phase));
        rig.ctrl.staffEndSession();
        async.flushMicrotasks();

        expect(seen, isNot(contains(SessionPhase.farewell)));
        expect(rig.ctrl.current.phase, SessionPhase.atDesk);
        rig.dispose();
      });
    });

    test('visitorEndedTour bị bỏ qua ngoài phiên tham quan', () {
      fakeAsync((async) {
        final rig = Rig(() => DateTime(2026).add(async.elapsed));
        rig.ctrl.start();
        rig.ctrl.visitorEndedTour(); // đang atDesk
        async.flushMicrotasks();
        expect(rig.ctrl.current.phase, SessionPhase.atDesk);
        rig.dispose();
      });
    });
  });
}
