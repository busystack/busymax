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
}
