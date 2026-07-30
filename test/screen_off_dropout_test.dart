// Destination: test/screen_off_dropout_test.dart
// Run with: flutter test test/screen_off_dropout_test.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// CHỨNG MINH CHUỖI NHÂN QUẢ CỦA LỖI "TẮT MÀN HÌNH TRÊN REDMI NOTE 12"
// ═══════════════════════════════════════════════════════════════════════════
//
// Thực địa (Redmi Note 12 / Android 15) báo ba triệu chứng khi tắt màn hình:
//   1. Audio đang phát vẫn chạy hết.
//   2. Hết intro KHÔNG tự sang audio hiện vật 1.
//   3. Đi ra đi vô, chuyển khu cũng không nghe chime.
// Redmi A1 (Android 12) hoàn hảo.
//
// Giả thuyết cần chứng minh: cả ba là HỆ QUẢ của MỘT nguyên nhân duy nhất —
// sóng beacon về thành cụm khi màn tắt — chứ không phải ba lỗi riêng ở tầng
// audio. Không có gì trong app "biết" màn hình đang tắt; nếu giả thuyết đúng
// thì chỉ cần một KHOẢNG TRỐNG SÓNG là tái hiện được đủ triệu chứng, ngay
// trên máy dev, không cần thiết bị.
//
// File này chứng minh HAI NỬA của chuỗi, tách bạch:
//
//   NỬA A (tầng audio, tất định, không dính thời gian):
//     leaveToStandby() ⇒ auto-tour chết. Không phải Luật 5, không phải codec,
//     không phải mất sóng hiện vật.
//
//   NỬA B (tầng radio, fake_async, đo được):
//     một khoảng trống sóng N giây ⇒ arbiter nhả về standby, và N ngưỡng đó
//     bằng ĐÚNG staleness + zoneSilence. Đây là thứ sinh ra leaveToStandby ở
//     nửa A.
//
// ⚠ CÁI FILE NÀY KHÔNG CHỨNG MINH: rằng sóng THẬT SỰ về thành cụm khi màn
// tắt. Đó là hành vi của Android/ROM, chỉ đo được trên máy thật bằng
// logcat (xem README của đợt sửa). File này chứng minh phần còn lại: NẾU có
// khoảng trống thì đủ để tạo ra chính xác các triệu chứng đã quan sát — và
// quan trọng không kém, chỉ ra đúng cái núm làm nó biến mất.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/data/processors/beacon_tracker_registry.dart';
import 'package:beacon_client/data/processors/zone_arbiter.dart';
import 'package:beacon_client/data/repositories/mock_zone_repository.dart';
import 'package:beacon_client/domain/models/audio_queue_state.dart';
import 'package:beacon_client/domain/models/beacon_reading.dart';
import 'package:beacon_client/domain/models/museum_config.dart';
import 'package:beacon_client/domain/models/zone_presence.dart';
import 'package:beacon_client/services/tour_audio_controller.dart';

import 'fakes/fake_audio_engine.dart';

const _kUuid = '4d6fc88b-be75-6698-da48-6866a36ec78e';
final _t0 = DateTime(2026, 7, 30, 9, 0, 0);

// ───────────────────────────────────────────────────────────── NỬA A: audio

Future<({TourAudioController ctrl, FakeAudioEngine engine, int Function() chimes})>
    _audioHarness() async {
  final repo = MockZoneRepository(simulatedLatency: Duration.zero);
  await repo.preWarm();
  final engine = FakeAudioEngine();
  var chimes = 0;
  final ctrl = TourAudioController(
    repository: repo,
    engine: engine,
    headphones: FakeHeadphoneMonitor(connected: true),
    uriResolver: (p) => Uri.parse('file:///bundle/$p'),
    language: () => 'vi',
    onChime: () => chimes++,
  );
  return (ctrl: ctrl, engine: engine, chimes: () => chimes);
}

// ───────────────────────────────────────────────────────────── NỬA B: radio

/// Phát sóng major [major] đều đặn trong [heard], im lặng [silent], rồi trả về
/// mốc thời gian (tính từ gói CUỐI CÙNG) mà arbiter nhả `currentMajor` về null.
///
/// null = không bao giờ nhả trong cửa sổ im lặng đó.
Duration? _timeToStandby({
  required int major,
  required Duration heard,
  required Duration silent,
  required ArbitrationParams params,
}) {
  Duration? released;

  fakeAsync((async) {
    DateTime now() => _t0.add(async.elapsed);
    final registry = BeaconTrackerRegistry(now: now);
    final arbiter = ZoneArbiter(deskMajor: 99, params: params, now: now);
    registry.zoneSignals.listen(arbiter.onSnapshot);

    Duration? lastHeardAt;
    arbiter.presence.listen((ZonePresence p) {
      final heardAt = lastHeardAt;
      if (p.currentMajor == null && released == null && heardAt != null) {
        released = async.elapsed - heardAt;
      }
    });

    registry.start();

    const step = Duration(milliseconds: 100);
    // Giai đoạn NGHE: bơm gói đều 100 ms để arbiter chốt được khu.
    for (var t = Duration.zero; t < heard; t += step) {
      registry.onReading(BeaconReading(
        uuid: _kUuid,
        major: major,
        minor: 1,
        rssi: -55, // khoẻ, thừa ngưỡng engage
        measuredPower: -59,
        timestamp: now(),
      ));
      lastHeardAt = async.elapsed;
      async.elapse(step);
    }

    // Giai đoạn IM LẶNG: không bơm gì, chỉ để đồng hồ chạy. Đây chính là
    // khoảng mù mà màn-hình-tắt tạo ra trên máy thật.
    async.elapse(silent);
    async.flushMicrotasks();

    arbiter.dispose();
    registry.dispose();
  });

  return released;
}

void main() {
  // ═════════════════════════════════════════════════════════════════════════
  group('NỬA A — leaveToStandby() một mình đủ giết auto-tour', () {
    // Đối chứng: đường đi BÌNH THƯỜNG. Cần có, nếu không thì test dưới không
    // chứng minh được gì — im lặng có thể do harness sai chứ không do bug.
    test('ĐỐI CHỨNG: không có dropout thì intro xong tự sang hiện vật', () async {
      final h = await _audioHarness();
      h.ctrl.enterZone(1);
      await Future<void>.delayed(Duration.zero);

      expect(h.engine.loadLog.single.clipKind, AudioClipKind.zoneIntro,
          reason: 'vào khu ⇒ nạp intro');

      h.engine.completeCurrent(); // decoder báo hết clip
      await Future<void>.delayed(Duration.zero);

      expect(h.engine.loadLog.length, 2, reason: 'intro xong ⇒ auto-advance');
      expect(h.engine.loadLog.last.clipKind, AudioClipKind.exhibitAuto);
      expect(h.ctrl.activeZoneMajor, 1);
    });

    test('TRIỆU CHỨNG 2: dropout giữa intro ⇒ intro xong KHÔNG sang hiện vật',
        () async {
      final h = await _audioHarness();
      h.ctrl.enterZone(1);
      await Future<void>.delayed(Duration.zero);
      expect(h.engine.loadLog.length, 1);

      // Đây là TOÀN BỘ thứ mà "màn hình tắt" gây ra ở tầng audio: một
      // LeftToStandby do rớt sóng. Không đụng gì tới Luật 5, codec, hay
      // _visitedZones.
      h.ctrl.leaveToStandby();
      await Future<void>.delayed(Duration.zero);

      expect(h.ctrl.activeZoneMajor, isNull,
          reason: 'leaveToStandby xoá khu đang hoạt động');

      // Khách vẫn nghe nốt clip đang phát (triệu chứng 1) rồi decoder báo hết.
      h.engine.completeCurrent();
      await Future<void>.delayed(Duration.zero);

      expect(
        h.engine.loadLog.where((r) => r.clipKind == AudioClipKind.exhibitAuto),
        isEmpty,
        reason: 'TourAudioController._onCompleted return sớm ở `major == null` '
            '⇒ auto-tour chết. Khớp đúng báo cáo thực địa.',
      );
    });

    test('TRIỆU CHỨNG 3: chime chỉ phát khi CÓ sự kiện zone — mù sóng thì câm',
        () async {
      final h = await _audioHarness();
      h.ctrl.enterZone(1);
      await Future<void>.delayed(Duration.zero);
      final afterEntry = h.chimes();

      // Khách đi ra rồi đi vào lại NHƯNG radio đang mù ⇒ không sự kiện nào tới
      // controller. Mô phỏng đúng bằng cách... không gọi gì cả.
      await Future<void>.delayed(Duration.zero);

      expect(h.chimes(), afterEntry,
          reason: 'chime nằm sau sự kiện zone, không có nguồn phát nào khác');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('NỬA B — khoảng trống sóng bao lâu thì nhả về standby', () {
    final defaults = ArbitrationParams.defaults(); // zoneSilence = 8s

    test('ĐỐI CHỨNG: sóng liên tục thì KHÔNG bao giờ nhả', () {
      final released = _timeToStandby(
        major: 1,
        heard: const Duration(seconds: 30),
        silent: Duration.zero,
        params: defaults,
      );
      expect(released, isNull);
    });

    test('mất sóng ⇒ nhả về standby ở ~staleness(3s) + zoneSilence(8s)', () {
      final released = _timeToStandby(
        major: 1,
        heard: const Duration(seconds: 20),
        silent: const Duration(seconds: 90),
        params: defaults,
      );

      expect(released, isNotNull, reason: 'phải nhả trong 90s im lặng');
      // Tracker ngừng bỏ phiếu sau staleness 3s, arbiter đếm tiếp zoneSilence
      // 8s từ lần cuối NGHE THẤY khu ⇒ ~11s. Biên ±2s cho nhịp sweep 1 Hz.
      expect(released!.inSeconds, inInclusiveRange(9, 13),
          reason: 'CHÍNH LÀ con số quyết định: khoảng mù >~11s là mất khu');
    });

    test(
        'khoảng mù 60s ĐƯỢC BẮC QUA khi nâng zoneSilence lên trần 60s '
        '(phép thử sửa được từ manifest, không cần build lại app)', () {
      final relaxed = ArbitrationParams.clamped(
        minDeltaDb: 7,
        dwellSeconds: 3,
        lockoutSeconds: 12,
        zoneSilenceSeconds: 60, // trần cho phép của schema
        deskDwellSeconds: 10,
        sessionSilenceMinutes: 10,
      );

      // Khoảng mù 50s — nhỏ hơn 3s + 60s nên phải sống sót.
      expect(
        _timeToStandby(
            major: 1,
            heard: const Duration(seconds: 20),
            silent: const Duration(seconds: 50),
            params: relaxed),
        isNull,
        reason: 'nới zoneSilence ⇒ rớt sóng 50s không còn giết khu',
      );

      // ...nhưng khoảng mù 80s (đúng cỡ đo được ngoài thực địa) thì TRẦN 60s
      // của schema VẪN KHÔNG đủ. Đây là lý do sửa manifest chỉ là phép thử
      // chẩn đoán, không phải lời giải cuối cùng.
      expect(
        _timeToStandby(
            major: 1,
            heard: const Duration(seconds: 20),
            silent: const Duration(seconds: 80),
            params: relaxed),
        isNotNull,
        reason: 'trần 60s không bắc qua nổi khoảng mù 80s ⇒ cần sửa ở code',
      );
    });
  });
}
