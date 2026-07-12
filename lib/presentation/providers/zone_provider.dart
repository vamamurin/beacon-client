// Destination: lib/presentation/providers/zone_provider.dart (REPLACES current)
//
// Thin ChangeNotifier over an enriched zone-status stream. Gives the UI the
// current zone (resolved ZoneInfo) or null for standby/radar.
//
// Takes a Stream + initial value rather than a ZonePresenceService: the
// provider never needed the service, only its output. Depending on the concrete
// service dragged ZoneArbiter, BeaconTrackerRegistry and an IBeaconScanner into
// every widget test of screen 2. Now a test drives it with Stream.value().
//
// `initial` MUST come from the service's cached currentStatus, never from
// ZoneStatus.standby: providers are lazy, so this is constructed when ZoneScreen
// first mounts — possibly long after the arbiter settled on a zone. Seeding with
// standby would flash the radar screen for one frame while already inside a zone.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/interfaces/i_zone_repository.dart';
import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/services/nearby_zones_tracker.dart';
import 'package:beacon_client/services/zone_presence_service.dart';

/// One row in the screen-2 ranking: a resolved zone plus display metadata.
/// [isCurrent] marks the arbiter-confirmed (engaged) zone — pinned to the top
/// with the "Đang ở đây" label. [distanceMeters] feeds the optional debug
/// readout. Non-current rows are numbered by their position.
@immutable
class RankedZone {
  final ZoneInfo zone;
  final bool isCurrent;
  final double? distanceMeters;

  const RankedZone({
    required this.zone,
    required this.isCurrent,
    this.distanceMeters,
  });

  @override
  bool operator ==(Object other) =>
      other is RankedZone &&
      other.zone.major == zone.major &&
      other.isCurrent == isCurrent &&
      other.distanceMeters == distanceMeters;

  @override
  int get hashCode => Object.hash(zone.major, isCurrent, distanceMeters);
}

class ZoneProvider extends ChangeNotifier {
  ZoneProvider({
    required Stream<ZoneStatus> status,
    required ZoneStatus initial,
    required Stream<List<NearbyZone>> ranking,
    required List<NearbyZone> initialRanking,
    required IZoneRepository repository,
  })  : _status = initial,
        _ranking = initialRanking,
        _repo = repository {
    // Seed BEFORE subscribing. The old code listened first and assigned
    // currentStatus afterwards, so a synchronously-emitting stream would have
    // its first value silently overwritten. The production broadcast stream
    // never emits sync; a test stream can.
    _sub = status.listen((s) {
      _status = s;
      notifyListeners();
    });
    _rankSub = ranking.listen((r) {
      _ranking = r;
      notifyListeners();
    });
  }

  late final StreamSubscription<ZoneStatus> _sub;
  late final StreamSubscription<List<NearbyZone>> _rankSub;
  final IZoneRepository _repo;

  ZoneStatus _status;
  ZoneStatus get status => _status;

  List<NearbyZone> _ranking;

  /// Current zone, or null when in standby (show the radar screen).
  ZoneInfo? get currentZone => _status.zone;
  bool get inZone => _status.inZone;

  /// True only when NOTHING is heard at all -> radar screen. If any zone is
  /// audible (even without an engaged current zone) we show the list instead.
  bool get isStandby => _status.zone == null && _ranking.isEmpty;

  /// The ordered rows for screen 2. The engaged zone is pinned first with
  /// isCurrent=true (even if it briefly dropped out of the audible set during
  /// lockout — audio is still playing it). Remaining audible zones follow,
  /// nearest first, de-duplicated against the pinned current zone.
  List<RankedZone> get rankedZones {
    final rows = <RankedZone>[];
    final current = _status.zone;

    if (current != null) {
      // Distance of the current zone if it's still audible, else null.
      final match = _firstOrNull(_ranking, (z) => z.major == current.major);
      rows.add(RankedZone(
        zone: current,
        isCurrent: true,
        distanceMeters: match?.distanceMeters,
      ));
    }

    for (final nz in _ranking) {
      if (current != null && nz.major == current.major) continue; // pinned
      final zone = _repo.zoneByMajor(nz.major);
      if (zone == null) continue; // unknown major (e.g. desk) -> skip
      rows.add(RankedZone(
        zone: zone,
        isCurrent: false,
        distanceMeters: nz.distanceMeters,
      ));
    }
    return rows;
  }

  static NearbyZone? _firstOrNull(
      List<NearbyZone> list, bool Function(NearbyZone) test) {
    for (final e in list) {
      if (test(e)) return e;
    }
    return null;
  }

  @override
  void dispose() {
    _sub.cancel();
    _rankSub.cancel();
    super.dispose();
  }
}