// Destination: lib/presentation/app/app_restarter.dart (NEW)
//
// A tiny, dependency-free handle that lets code deep in the widget tree (the
// Gate's sync notice) trigger a FULL app-graph rebuild — re-running
// Injection.build() so the radio pipeline picks up a just-synced config.
//
// Why a rebuild is needed (not just a re-warm): on a fresh device the graph is
// built while the bundle is missing, so the beacon UUID filter, arbiter params
// and language are all defaults/empty. Re-warming the repository loads content
// into memory but does NOT re-wire those already-constructed services; only a
// fresh Injection.build() does. Provided from the bootstrap host and consumed
// via Provider, so nothing reaches for a global singleton.

class AppRestarter {
  const AppRestarter(this._run);
  final Future<void> Function() _run;

  /// Tear down the current graph and rebuild it from scratch.
  Future<void> call() => _run();
}
