// Destination: test/data/analytics/analytics_uploader_test.dart
//
// Pins the cleartext-upload policy.
//
// `isPrivateHost` no longer decides whether an upload happens (REQUIRE_HTTPS
// does). It decides whether cleartext to a given host gets a loud warning — the
// safety net that keeps a forgotten REQUIRE_HTTPS flag from shipping silently.
// A wrong answer here means either warning-spam on a normal LAN deployment, or
// no warning at all when analytics really are crossing the public internet in
// the clear. Both are worth a test.
//
// The strict path is compile-time, so to exercise it run:
//   flutter test --dart-define=REQUIRE_HTTPS=true

import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/data/analytics/analytics_uploader.dart';

void main() {
  group('isPrivateHost — LAN/loopback, cleartext is expected here (no warning)',
      () {
    for (final host in <String>[
      'localhost',
      '127.0.0.1',
      '10.0.0.5',
      '192.168.1.8', // the LAN dev server this policy was debugged against
      '172.16.0.1', // low edge of 172.16.0.0/12
      '172.31.255.254', // high edge of 172.16.0.0/12
      '169.254.10.10', // link-local
      '::1', // IPv6 loopback
      'fd00::1', // IPv6 unique local (fc00::/7)
      'fe80::1', // IPv6 link-local
    ]) {
      test(host, () {
        expect(HttpAnalyticsUploader.isPrivateHost(host), isTrue);
      });
    }
  });

  group('isPrivateHost — public or unprovable, cleartext deserves a warning',
      () {
    for (final host in <String>[
      '8.8.8.8',
      '1.1.1.1',
      '172.15.0.1', // just BELOW the 172.16/12 block
      '172.32.0.1', // just ABOVE the 172.16/12 block
      '192.169.1.1', // near-miss on 192.168/16
      '11.0.0.1', // near-miss on 10/8
      '2001:4860:4860::8888', // public IPv6
      // Hostnames are never "provably local": DNS is not a security boundary.
      'cms.museum.example',
      'analytics.internal',
    ]) {
      test(host, () {
        expect(HttpAnalyticsUploader.isPrivateHost(host), isFalse);
      });
    }
  });

  test('default build is permissive (REQUIRE_HTTPS not defined)', () {
    // Guards against someone flipping defaultValue to true and silently
    // re-breaking every LAN dev/profile run — the exact regression this policy
    // exists to prevent. Under --dart-define=REQUIRE_HTTPS=true this test is
    // expected to fail; that is the point of the flag.
    expect(HttpAnalyticsUploader.requireHttps, isFalse);
  });
}