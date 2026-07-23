// Destination: lib/data/analytics/noop_analytics_sink.dart
//
// Mock-mode sink: swallows everything. Keeps the recorder fully wired on
// desktop/dev (so its logic is exercised) without writing files or hitting the
// network. Mirrors NoopKeepAlive.

import 'package:beacon_client/domain/interfaces/i_analytics_sink.dart';
import 'package:beacon_client/domain/models/analytics_event.dart';

class NoopAnalyticsSink implements IAnalyticsSink {
  const NoopAnalyticsSink();

  @override
  void record(AnalyticsEvent event) {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> drain() async {}

  @override
  Future<void> dispose() async {}
}