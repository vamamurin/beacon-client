// Destination: lib/domain/models/tour_progress.dart
//
// Ảnh chụp TIẾN TRÌNH của một chuyến tham quan: đã ghé khu nào, đã nghe hiện
// vật nào, đi được bao lâu.
//
// Vì sao cần một mô hình riêng thay vì đọc ké chỗ khác:
//   • `TourAudioController._visitedZones` trông rất giống thứ ta cần, nhưng nó
//     là BỘ NHỚ CỦA TẦNG AUDIO trả lời câu hỏi "intro khu này phát chưa" để
//     quyết định có phát lại lời chào không. Nối màn tổng kết vào đó là buộc
//     hai thứ khác bản chất phải thay đổi cùng nhau.
//   • `AnalyticsRecorder` có đủ dữ liệu nhưng đẩy một chiều xuống sink rồi
//     quên; nó cố tình không giữ trạng thái đọc được.
// Nên đây là một mô hình thứ ba, đọc cùng các stream đó nhưng phục vụ MÀN HÌNH.

import 'package:flutter/foundation.dart';

/// Khoá của một hiện vật trong phạm vi toàn bảo tàng.
///
/// Phải là CẶP (major, minor): minor chỉ duy nhất TRONG một khu, nên một
/// `Set<int>` các minor sẽ trộn lẫn hiện vật số 1 của khu A với số 1 của khu B.
@immutable
class ExhibitKey {
  final int major;
  final int minor;

  const ExhibitKey(this.major, this.minor);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExhibitKey && other.major == major && other.minor == minor);

  @override
  int get hashCode => Object.hash(major, minor);

  @override
  String toString() => '$major/$minor';
}

@immutable
class TourProgress {
  /// Các khu đã thực sự bước vào (EnteredZone / ChangedZone).
  final Set<int> visitedMajors;

  /// Hiện vật đã nghe HẾT — clip kết thúc tự nhiên.
  final Set<ExhibitKey> heardExhibits;

  /// Hiện vật đã bắt đầu phát nhưng chưa chắc nghe hết. Luôn là tập cha của
  /// [heardExhibits]; dùng [partialExhibits] khi cần phần "nghe dở".
  final Set<ExhibitKey> startedExhibits;

  /// Mốc bắt đầu tour. Null khi chưa có tour nào chạy trong vòng đời tiến trình.
  final DateTime? startedAt;

  /// Tổng số khu / hiện vật trong bundle, chụp lại tại thời điểm snapshot. Nằm
  /// trong snapshot chứ không để UI tự đếm, để tử số và mẫu số luôn được đọc
  /// từ cùng một khoảnh khắc.
  final int totalZones;
  final int totalExhibits;

  const TourProgress({
    required this.visitedMajors,
    required this.heardExhibits,
    required this.startedExhibits,
    required this.startedAt,
    required this.totalZones,
    required this.totalExhibits,
  });

  static const TourProgress empty = TourProgress(
    visitedMajors: <int>{},
    heardExhibits: <ExhibitKey>{},
    startedExhibits: <ExhibitKey>{},
    startedAt: null,
    totalZones: 0,
    totalExhibits: 0,
  );

  /// Đã bắt đầu nhưng chưa nghe hết.
  Set<ExhibitKey> get partialExhibits =>
      startedExhibits.difference(heardExhibits);

  /// Thời gian đã đi, tính tại [now]. Truyền `now` vào thay vì đóng băng lúc
  /// snapshot để màn tổng kết hiện được con số tươi mà không cần service phát
  /// lại mỗi giây.
  Duration elapsedAt(DateTime now) {
    final start = startedAt;
    if (start == null) return Duration.zero;
    final d = now.difference(start);
    return d.isNegative ? Duration.zero : d;
  }

  /// Chưa ghé khu nào và chưa nghe gì — màn tổng kết hiện trạng thái rỗng.
  bool get isUntouched => visitedMajors.isEmpty && startedExhibits.isEmpty;

  /// Đã bước vào mọi khu của bảo tàng.
  ///
  /// Đây là điều kiện để GỢI Ý xem tổng kết, KHÔNG phải để tự đẩy khách sang
  /// màn tổng kết: cắt ngang một người đang nghe thuyết minh vì họ vừa bước
  /// qua ngưỡng cửa khu cuối là hành vi thù địch.
  bool get hasVisitedEveryZone =>
      totalZones > 0 && visitedMajors.length >= totalZones;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TourProgress &&
        setEquals(other.visitedMajors, visitedMajors) &&
        setEquals(other.heardExhibits, heardExhibits) &&
        setEquals(other.startedExhibits, startedExhibits) &&
        other.startedAt == startedAt &&
        other.totalZones == totalZones &&
        other.totalExhibits == totalExhibits;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(visitedMajors),
        Object.hashAllUnordered(heardExhibits),
        Object.hashAllUnordered(startedExhibits),
        startedAt,
        totalZones,
        totalExhibits,
      );

  @override
  String toString() => 'TourProgress(khu ${visitedMajors.length}/$totalZones, '
      'hiện vật ${heardExhibits.length}/$totalExhibits)';
}
