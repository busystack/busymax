import 'dart:io';

import 'package:busymax/src/android/presentation/android_settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes local DNS names and private IPv4 ranges', () {
    for (final host in [
      'nextcloud',
      'cloud.local',
      'cloud.lan',
      '10.0.0.4',
      '172.31.2.3',
      '192.168.1.9',
      '169.254.10.20',
    ]) {
      expect(isAndroidLocalNetworkHost(host), isTrue, reason: host);
    }
  });

  test(
    'loopback remains exempt when native route information is unavailable',
    () async {
      for (final host in [
        'localhost',
        '127.0.0.1',
        '127.255.255.255',
        '::1',
        '[::1]',
      ]) {
        expect(isAndroidLocalNetworkHost(host), isFalse, reason: host);
        expect(
          await requiresAndroidLocalNetworkAccess(
            host,
            routeCheck: (_) async => null,
            lookup: (_) async => [InternetAddress.loopbackIPv4],
          ),
          isFalse,
          reason: host,
        );
      }
      expect(
        await requiresAndroidLocalNetworkAccess(
          'qa.example.test',
          routeCheck: (_) async => null,
          lookup: (_) async => [
            InternetAddress.loopbackIPv4,
            InternetAddress.loopbackIPv6,
          ],
        ),
        isFalse,
      );
    },
  );

  test('CGNAT and multicast hints have exact boundaries', () {
    for (final host in [
      '100.64.0.0',
      '100.127.255.255',
      '224.0.0.0',
      '239.255.255.255',
      '255.255.255.255',
      'ff02::1',
      '[fe80::1%25wlan0]',
    ]) {
      expect(isAndroidLocalNetworkHost(host), isTrue, reason: host);
    }
    for (final host in [
      '100.63.255.255',
      '100.128.0.0',
      '223.255.255.255',
      '240.0.0.0',
      '2001:db8::1',
    ]) {
      expect(isAndroidLocalNetworkHost(host), isFalse, reason: host);
    }
  });
  test('native route evidence overrides prefix hints for VPN, cellular and directly connected IPv6', () async {
    expect(
      await requiresAndroidLocalNetworkAccess(
        '100.64.0.1',
        routeCheck: (_) async => false,
      ),
      isFalse,
    );
    expect(
      await requiresAndroidLocalNetworkAccess(
        '2001:db8:1::20',
        routeCheck: (_) async => true,
      ),
      isTrue,
    );
    expect(
      await requiresAndroidLocalNetworkAccess(
        'cloud.example.test',
        routeCheck: (_) async => false,
        lookup: (_) => throw StateError('route result is authoritative'),
      ),
      isFalse,
    );
    expect(
      await requiresAndroidLocalNetworkAccess(
        'cloud.example.test',
        routeCheck: (_) async => null,
        lookup: (_) async => [InternetAddress('100.64.0.1')],
      ),
      isTrue,
    );
  });

  test('recognizes private and link-local IPv6 ranges', () {
    expect(isAndroidLocalNetworkHost('::1'), isFalse);
    expect(isAndroidLocalNetworkHost('fd12:3456::1'), isTrue);
    expect(isAndroidLocalNetworkHost('fe80::a'), isTrue);
  });

  test('does not classify public hosts and addresses as local', () {
    expect(isAndroidLocalNetworkHost('cloud.example.com'), isFalse);
    expect(isAndroidLocalNetworkHost('8.8.8.8'), isFalse);
    expect(isAndroidLocalNetworkHost('2001:4860:4860::8888'), isFalse);
  });

  test(
    'resolves an ordinary dotted DNS name to its actual LAN address',
    () async {
      expect(
        await requiresAndroidLocalNetworkAccess(
          'cloud.example.com',
          lookup: (_) async => [InternetAddress('192.168.1.20')],
        ),
        isTrue,
      );
    },
  );

  test('does not prompt when an ordinary DNS name resolves publicly', () async {
    expect(
      await requiresAndroidLocalNetworkAccess(
        'cloud.example.com',
        lookup: (_) async => [InternetAddress('203.0.113.10')],
      ),
      isFalse,
    );
  });

  test(
    'mixed DNS answers require LAN access and lookup failure does not',
    () async {
      expect(
        await requiresAndroidLocalNetworkAccess(
          'cloud.example.com',
          lookup: (_) async => [
            InternetAddress('203.0.113.10'),
            InternetAddress('fd12:3456::1'),
          ],
        ),
        isTrue,
      );
      expect(
        await requiresAndroidLocalNetworkAccess(
          'missing.example.com',
          lookup: (_) => throw const SocketException('unresolved'),
        ),
        isFalse,
      );
    },
  );
}
