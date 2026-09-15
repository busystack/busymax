import 'dart:io';

import 'package:busymax/src/android/presentation/android_settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes local DNS names and private IPv4 ranges', () {
    for (final host in [
      'localhost',
      'nextcloud',
      'cloud.local',
      'cloud.lan',
      '10.0.0.4',
      '172.31.2.3',
      '192.168.1.9',
      '127.0.0.1',
      '169.254.10.20',
    ]) {
      expect(isAndroidLocalNetworkHost(host), isTrue, reason: host);
    }
  });

  test('recognizes private and link-local IPv6 ranges', () {
    expect(isAndroidLocalNetworkHost('::1'), isTrue);
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
