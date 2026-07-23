// Destination: lib/domain/models/analytics_event.dart
//
// The vocabulary of the analytics layer — the FACTS a tour produces, nothing
// about transport or storage. Mirrors the ZoneEvent design: a sealed base so
// the recorder/sink switch is exhaustive, small immutable subclasses, and a
// self-describing toJson() envelope.
//
// Design rules (match the rest of the codebase):
//   • PII-free by construction. There is no visitor identity here — only an
//     anonymous per-tour [sessionId] the recorder assigns, so events from the
//     same walkthrough can be grouped without ever identifying a person.
//   • Time is carried explicitly ([at], stamped by the recorder from its
//     injected clock) so serialized events are deterministic in tests.
//   • Durations serialize as integer milliseconds; enums as their `.name`;
//     [at] as an ISO-8601 UTC string. Server owns any further math (e.g.
//     completion ratio) so the client never divides by a null/zero duration.
//
// WHY these particular events: this is a *proximity marketing* product, so the
// dataset has to answer the marketing questions the audio-guide framing can't:
//   TourStarted / TourEnded  → the funnel (starts, completion, why it ended).
//   ZoneDwell                → the heatmap (which halls hold attention, and for
//                              how long) + whether arrival was a first entry or
//                              a mid-tour switch.
//   ExhibitPlayed / Finished → per-exhibit engagement + completion (did they
//                              hear it out, or skip after a few seconds), split
//                              by auto-tour vs an explicit tap.

import 'package:flutter/foundation.dart';

import 'package:beacon_client/domain/models/audio_queue_state.dart' show AudioClipKind;
import 'package:beacon_client/domain/models/tour_session.dart' show SessionEndReason;

/// How the visitor arrived in a zone whose dwell we're closing.
enum ZoneEntryKind {
  /// Entered from standby (no previous zone) — a fresh acquisition.
  entered,

  /// Switched directly from another zone (arbiter takeover / confirmed change).
  changed,
}

/// Base type for every analytics fact. [sessionId] groups all events of one
/// tour; [at] is when the fact occurred (recorder's clock).
@immutable
sealed class AnalyticsEvent {
  final String sessionId;
  final DateTime at;

  const AnalyticsEvent({required this.sessionId, required this.at});

  /// Stable event name used as the JSON discriminator and the server's table
  /// key. Never rename without a schema bump.
  String get name;

  /// Event-specific payload (everything except the common envelope fields).
  Map<String, Object?> payload();

  /// Full JSON line: envelope (name/sessionId/at) + payload. The sink wraps
  /// this again with device + schema before persisting.
  Map<String, Object?> toJson() => {
        'name': name,
        'sessionId': sessionId,
        'at': at.toUtc().toIso8601String(),
        ...payload(),
      };
}

/// A tour began (session gate -> touring, on an explicit Start).
class TourStarted extends AnalyticsEvent {
  /// Language code active at the moment of Start (visitor's choice).
  final String language;

  /// Whether a private-listening route existed at Start. Distinguishes a
  /// listening tour from a reading-mode tour in aggregate.
  final bool headphones;

  const TourStarted({
    required super.sessionId,
    required super.at,
    required this.language,
    required this.headphones,
  });

  @override
  String get name => 'tour_started';

  @override
  Map<String, Object?> payload() => {
        'language': language,
        'headphones': headphones,
      };
}

/// A tour ended, with the reason the SessionController recorded and the total
/// wall-clock duration from Start to end.
class TourEnded extends AnalyticsEvent {
  /// May be null in the rare case the phase left touring with no reason set.
  final SessionEndReason? reason;
  final Duration duration;

  const TourEnded({
    required super.sessionId,
    required super.at,
    required this.reason,
    required this.duration,
  });

  @override
  String get name => 'tour_ended';

  @override
  Map<String, Object?> payload() => {
        'reason': reason?.name,
        'durationMs': duration.inMilliseconds,
      };
}

/// Time spent continuously present in one zone, emitted when the visitor leaves
/// it (switch, standby, or tour end).
class ZoneDwell extends AnalyticsEvent {
  final int major;
  final Duration duration;
  final ZoneEntryKind entry;

  const ZoneDwell({
    required super.sessionId,
    required super.at,
    required this.major,
    required this.duration,
    required this.entry,
  });

  @override
  String get name => 'zone_dwell';

  @override
  Map<String, Object?> payload() => {
        'major': major,
        'dwellMs': duration.inMilliseconds,
        'entry': entry.name,
      };
}

/// A narration clip started producing sound. One per play-start (a pause/resume
/// of the same clip does NOT re-emit).
class ExhibitPlayed extends AnalyticsEvent {
  final int major;

  /// Null for a zone intro; otherwise the exhibit's minor.
  final int? minor;
  final AudioClipKind kind;

  const ExhibitPlayed({
    required super.sessionId,
    required super.at,
    required this.major,
    required this.minor,
    required this.kind,
  });

  @override
  String get name => 'exhibit_played';

  @override
  Map<String, Object?> payload() => {
        'major': major,
        'minor': minor,
        'kind': kind.name,
      };
}

/// A clip stopped being the active clip. [completed] separates "heard to the
/// natural end" from "cut short" (superseded by another clip, zone change, stop
/// or session end). [listened] is the wall-clock time it was the active clip;
/// [total] is the clip's known length (may be null if no duration hint).
class ExhibitFinished extends AnalyticsEvent {
  final int major;
  final int? minor;
  final AudioClipKind kind;
  final Duration listened;
  final Duration? total;
  final bool completed;

  const ExhibitFinished({
    required super.sessionId,
    required super.at,
    required this.major,
    required this.minor,
    required this.kind,
    required this.listened,
    required this.total,
    required this.completed,
  });

  @override
  String get name => 'exhibit_finished';

  @override
  Map<String, Object?> payload() => {
        'major': major,
        'minor': minor,
        'kind': kind.name,
        'listenedMs': listened.inMilliseconds,
        'totalMs': total?.inMilliseconds,
        'completed': completed,
      };
}