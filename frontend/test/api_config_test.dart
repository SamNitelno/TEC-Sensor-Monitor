import 'package:flutter_test/flutter_test.dart';
import 'package:tek_sensor_monitor/core/api_config.dart';

void main() {
  test('isPrivateLanHost detects RFC1918 addresses', () {
    expect(isPrivateLanHost('192.168.1.100'), isTrue);
    expect(isPrivateLanHost('10.0.0.5'), isTrue);
    expect(isPrivateLanHost('172.16.1.1'), isTrue);
    expect(isPrivateLanHost('10.0.2.2'), isFalse);
    expect(isPrivateLanHost('example.com'), isFalse);
  });

  test('resolveApiBaseUrl preserves public hosts on desktop test runner', () {
    expect(resolveApiBaseUrl('https://example.com'), 'https://example.com');
  });

  test('resolveApiBaseUrl preserves LAN IPs on test runner (non-Android)', () {
    expect(
      resolveApiBaseUrl('http://192.168.1.100:8000'),
      'http://192.168.1.100:8000',
    );
  });

  test('resolveApiBaseUrl preserves LAN hostnames on test runner', () {
    expect(
      resolveApiBaseUrl('https://tek-server.local'),
      'https://tek-server.local',
    );
  });

  test('validateApiBaseUrlInput accepts http and https URLs', () {
    expect(validateApiBaseUrlInput('https://192.168.1.100'), isNull);
    expect(validateApiBaseUrlInput('http://192.168.1.100:8000'), isNull);
    expect(validateApiBaseUrlInput('ftp://192.168.1.100'), isNotNull);
    expect(validateApiBaseUrlInput(''), isNotNull);
  });

  test('normalizeApiBaseUrl strips trailing slashes', () {
    expect(normalizeApiBaseUrl('https://192.168.1.100/'), 'https://192.168.1.100');
  });

  test('computeApiBaseUrl prefers saved URL over dart-define default', () {
    expect(
      computeApiBaseUrl(savedUrl: 'https://saved.example:443'),
      'https://saved.example:443',
    );
  });
}
