import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class LocalNotifications {
  LocalNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool? _permissionGranted;

  static Future<void> init() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    try {
      await _plugin.initialize(settings);
    } catch (_) {
      // Platform plugins unavailable (e.g. widget tests).
    }
    _initialized = true;
  }

  static Future<bool> ensurePermission({bool requestIfNeeded = true}) async {
    if (kIsWeb) {
      return _ensureWebPermission(requestIfNeeded: requestIfNeeded);
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.status;
      if (status.isGranted) {
        _permissionGranted = true;
        return true;
      }
      if (!requestIfNeeded) {
        _permissionGranted = false;
        return false;
      }
      final result = await Permission.notification.request();
      _permissionGranted = result.isGranted;
      return result.isGranted;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios == null) return false;
      if (!requestIfNeeded) return _permissionGranted ?? false;
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      _permissionGranted = granted ?? false;
      return _permissionGranted!;
    }

    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      _permissionGranted = true;
      return true;
    }

    return false;
  }

  static Future<bool> _ensureWebPermission({required bool requestIfNeeded}) async {
    _permissionGranted = true;
    return true;
  }

  static bool get permissionGranted => _permissionGranted ?? false;

  static Future<void> openSystemSettings() async {
    await openAppSettings();
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'role_changes',
        'Изменения прав',
        channelDescription: 'Повышение и понижение пользователей',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(id, title, body, details);
  }
}
