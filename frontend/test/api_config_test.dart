import 'package:flutter_test/flutter_test.dart';
import 'package:tek_sensor_monitor/core/api_config.dart';

void main() {
  test('isPrivateLanHost detects RFC1918 addresses', () {
    expect(isPrivateLanHost('192.168.0.181'), isTrue);
    expect(isPrivateLanHost('10.0.0.5'), isTrue);
    expect(isPrivateLanHost('172.16.1.1'), isTrue);
    expect(isPrivateLanHost('10.0.2.2'), isFalse);
    expect(isPrivateLanHost('example.com'), isFalse);
  });

  test('resolveApiBaseUrl preserves public hosts on desktop test runner', () {
    expect(resolveApiBaseUrl('https://example.com'), 'https://example.com');
  });
}
