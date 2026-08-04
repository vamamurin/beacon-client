// Destination: lib/presentation/providers/tour_progress_provider.dart
//
// ChangeNotifier mỏng bọc TourProgressService, đúng khuôn SessionProvider: UI
// nghe provider, không bao giờ chạm vào service.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/models/tour_progress.dart';
import 'package:beacon_client/services/tour_progress_service.dart';

class TourProgressProvider extends ChangeNotifier {
  TourProgressProvider(this._service) {
    _progress = _service.current;
    _sub = _service.updates.listen((p) {
      _progress = p;
      notifyListeners();
    });
  }

  final TourProgressService _service;
  late final StreamSubscription<TourProgress> _sub;

  TourProgress _progress = TourProgress.empty;
  TourProgress get progress => _progress;

  /// Đã đi hết mọi khu — điều kiện GỢI Ý xem tổng kết (không tự chuyển màn;
  /// xem doc trên [TourProgress.hasVisitedEveryZone]).
  bool get hasVisitedEveryZone => _progress.hasVisitedEveryZone;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
