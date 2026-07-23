// Destination: lib/domain/interfaces/i_analytics_sink.dart
//
// Where analytics events go after the recorder builds them. Deliberately tiny
// and TRANSPORT-AGNOSTIC: the recorder depends on this, never on a concrete
// file/HTTP class, so it stays unit-testable with a fake and mock mode can drop
// events with a no-op.
//
// The three verbs mirror the content-sync lifecycle so the two subsystems feel
// the same:
//   record — non-blocking enqueue on the hot path. MUST NOT await (called from
//            stream handlers that follow the "no await across mutation" rule);
//            durability is [flush]'s job, not record's.
//   flush  — persist buffered events durably (survive a crash / kill). Call at
//            a natural boundary (tour end) and on app pause.
//   drain  — upload persisted events, then prune what uploaded. Call only at
//            atDesk/docked (same safe window as content sync) — never mid-tour.

import 'package:beacon_client/domain/models/analytics_event.dart';

abstract interface class IAnalyticsSink {
  /// Enqueue an event. Returns immediately; no I/O on the caller's path.
  void record(AnalyticsEvent event);

  /// Durably persist everything buffered so far. Safe to call repeatedly.
  Future<void> flush();

  /// Upload persisted events in batches and prune what succeeded. Safe to call
  /// when offline (a failed upload simply leaves events for next time). Only
  /// call while docked/atDesk.
  Future<void> drain();

  /// Flush then release resources (timers, file handles).
  Future<void> dispose();
}