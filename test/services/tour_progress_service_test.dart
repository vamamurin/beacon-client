// Destination: test/services/tour_progress_service_test.dart
//
// TourProgressService đọc CÙNG bốn stream với AnalyticsRecorder nhưng trả lời
// một câu hỏi khác: "màn tổng kết phải hiện con số nào". File này khoá đúng
// những chỗ hai bên khác nhau, và khoá hai quyết định dễ bị lật ngược sau này:
//
//   1. DỌN Ở ĐẦU TOUR, không phải ở cuối — vì màn tổng kết nằm TRONG phiên và
//      tự gọi endTour(); dọn ở cuối thì các con số biến mất ngay dưới tay khách.
//   2. Mẫu số đọc qua callback — kho nội dung nạp bất đồng bộ.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/domain/models/audio_queue_state.dart';
import 'package:beacon_client/domain/models/tour_progress.dart';
import 'package:beacon_client/domain/models/tour_session.dart';
import 'package:beacon_client/services/tour_progress_service.dart';
import 'package:beacon_client/services/zone_presence_service.dart';

/// Bàn thử: bốn stream nguồn + đồng hồ tiêm + mẫu số chỉnh được giữa chừng.
class _Harness {
  final session = StreamController<SessionState>.broadcast();
  final zones = StreamController<ZoneEvent>.broadcast();
  final audio = StreamController<AudioQueueState>.broadcast();
  final completed = StreamController<AudioTrackRef>.broadcast();

  final base = DateTime.utc(2026, 1, 1, 10, 0, 0);
  late DateTime clock = base;

  int totalZones = 2;
  int totalExhibits = 6;

  late final TourProgressService service = TourProgressService(
    sessionState: session.stream,
    zoneEvents: zones.stream,
    audioState: audio.stream,
    audioCompleted: completed.stream,
    totalZones: () => totalZones,
    totalExhibits: () => totalExhibits,
    now: () => clock,
  );

  void at(int sec) => clock = base.add(Duration(seconds: sec));

  Future<void> startTour() async {
    session.add(const SessionState(phase: SessionPhase.touring));
    await pumpEventQueue();
  }

  Future<void> endTour(
      [SessionEndReason reason = SessionEndReason.manual]) async {
    session.add(SessionState(phase: SessionPhase.ending, endReason: reason));
    session.add(SessionState(phase: SessionPhase.atDesk, endReason: reason));
    await pumpEventQueue();
  }

  Future<void> enter(int major) async {
    zones.add(EnteredZone(major));
    await pumpEventQueue();
  }

  Future<void> play(AudioTrackRef ref) async {
    audio.add(AudioQueueState(current: ref, status: PlaybackStatus.playing));
    await pumpEventQueue();
  }

  Future<void> finish(AudioTrackRef ref) async {
    completed.add(ref);
    await pumpEventQueue();
  }

  Future<void> dispose() async {
    await service.dispose();
    await session.close();
    await zones.close();
    await audio.close();
    await completed.close();
  }
}

const _introZ1 = AudioTrackRef.zoneIntro(1);
const _z1e1 = AudioTrackRef(
    zoneMajor: 1, exhibitMinor: 1, clipKind: AudioClipKind.exhibitAuto);
const _z1e2 = AudioTrackRef(
    zoneMajor: 1, exhibitMinor: 2, clipKind: AudioClipKind.exhibitAuto);
const _z2e1 = AudioTrackRef(
    zoneMajor: 2, exhibitMinor: 1, clipKind: AudioClipKind.exhibitManual);

void main() {
  late _Harness h;

  setUp(() {
    h = _Harness();
    // Chạm vào service để nó subscribe trước khi test bơm sự kiện.
    h.service;
  });

  tearDown(() => h.dispose());

  test('ghi nhận khu đã ghé và hiện vật đã nghe hết', () async {
    await h.startTour();
    await h.enter(1);
    await h.play(_introZ1);
    await h.finish(_introZ1);
    await h.play(_z1e1);
    await h.finish(_z1e1);
    await h.play(_z1e2); // bắt đầu nhưng bỏ dở

    final p = h.service.current;
    expect(p.visitedMajors, {1});
    expect(p.heardExhibits, {const ExhibitKey(1, 1)});
    expect(p.startedExhibits, {const ExhibitKey(1, 1), const ExhibitKey(1, 2)});
    expect(p.partialExhibits, {const ExhibitKey(1, 2)});
    expect(p.totalZones, 2);
    expect(p.totalExhibits, 6);
  });

  // Lời chào khu không nằm trong mẫu số "x/y hiện vật" nên cũng không được vào
  // tử số — nếu không, một khách chỉ đứng nghe hai lời chào sẽ thấy "2 hiện vật
  // đã nghe" mà chưa nghe hiện vật nào.
  test('lời chào khu không được tính là hiện vật', () async {
    await h.startTour();
    await h.enter(1);
    await h.play(_introZ1);
    await h.finish(_introZ1);

    expect(h.service.current.heardExhibits, isEmpty);
    expect(h.service.current.startedExhibits, isEmpty);
    expect(h.service.current.visitedMajors, {1});
  });

  // minor chỉ duy nhất TRONG một khu.
  test('hiện vật cùng minor ở hai khu là hai bản ghi khác nhau', () async {
    await h.startTour();
    await h.enter(1);
    await h.finish(_z1e1);
    await h.enter(2);
    await h.finish(_z2e1);

    expect(h.service.current.heardExhibits,
        {const ExhibitKey(1, 1), const ExhibitKey(2, 1)});
  });

  test('ChangedZone tính là đã ghé khu đích; về standby không xoá dấu chân',
      () async {
    await h.startTour();
    await h.enter(1);
    h.zones.add(const ChangedZone(1, 2));
    await pumpEventQueue();
    h.zones.add(const LeftToStandby());
    await pumpEventQueue();

    expect(h.service.current.visitedMajors, {1, 2});
  });

  test('nghe hết mà lỡ mất sự kiện bắt đầu thì started vẫn phủ heard', () async {
    await h.startTour();
    await h.finish(_z1e1); // chỉ có onCompleted, không có state playing

    final p = h.service.current;
    expect(p.heardExhibits, {const ExhibitKey(1, 1)});
    expect(p.startedExhibits, containsAll(p.heardExhibits));
    expect(p.partialExhibits, isEmpty);
  });

  test('sự kiện ngoài phiên bị bỏ qua', () async {
    await h.enter(1); // chưa vào tour
    await h.finish(_z1e1);
    expect(h.service.current, TourProgress.empty);

    await h.startTour();
    await h.enter(1);
    await h.endTour();
    await h.enter(2); // sau khi tour đã kết thúc
    expect(h.service.current.visitedMajors, {1});
  });

  // Quyết định 1: số liệu SỐNG QUA thời điểm rời touring, vì chính màn tổng kết
  // là thứ gọi endTour() và nó vẫn đang hiện trên màn hình lúc đó.
  test('rời phiên GIỮ số liệu; tour mới mới là lúc dọn', () async {
    await h.startTour();
    await h.enter(1);
    await h.finish(_z1e1);
    await h.endTour();

    expect(h.service.current.visitedMajors, {1});
    expect(h.service.current.heardExhibits, hasLength(1));

    await h.startTour();
    expect(h.service.current.visitedMajors, isEmpty);
    expect(h.service.current.heardExhibits, isEmpty);
    expect(h.service.current.startedExhibits, isEmpty);
  });

  test('elapsed đo từ mốc bắt đầu tour', () async {
    h.at(0);
    await h.startTour();
    h.at(125);
    expect(h.service.current.elapsedAt(h.clock), const Duration(seconds: 125));

    // Đồng hồ hệ thống bị chỉnh lùi không được đẻ ra thời lượng âm.
    expect(h.service.current.elapsedAt(h.base.subtract(const Duration(hours: 1))),
        Duration.zero);
  });

  test('hasVisitedEveryZone chỉ đúng khi đã ghé đủ mẫu số', () async {
    await h.startTour();
    await h.enter(1);
    expect(h.service.current.hasVisitedEveryZone, isFalse);
    await h.enter(2);
    expect(h.service.current.hasVisitedEveryZone, isTrue);
  });

  // Quyết định 2: kho nội dung nạp bất đồng bộ, nên mẫu số phải tươi ở MỖI
  // snapshot chứ không chụp một lần lúc dựng graph.
  test('mẫu số được đọc lại ở mỗi snapshot', () async {
    h.totalZones = 0;
    h.totalExhibits = 0;
    await h.startTour();
    expect(h.service.current.totalZones, 0);
    expect(h.service.current.hasVisitedEveryZone, isFalse); // 0 khu ≠ "đi hết"

    h.totalZones = 3;
    h.totalExhibits = 9;
    await h.enter(1);
    expect(h.service.current.totalZones, 3);
    expect(h.service.current.totalExhibits, 9);
  });

  test('chỉ phát khi snapshot thực sự đổi', () async {
    final seen = <TourProgress>[];
    final sub = h.service.updates.listen(seen.add);

    await h.startTour();
    await h.enter(1);
    await h.enter(1); // lặp lại: không có gì đổi
    await h.play(_z1e1);
    await h.play(_z1e1); // cùng ref, vẫn đang phát

    expect(seen, hasLength(3)); // bắt đầu tour, vào khu 1, phát hiện vật 1
    await sub.cancel();
  });
}
