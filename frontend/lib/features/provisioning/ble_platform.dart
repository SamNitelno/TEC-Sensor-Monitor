import 'package:flutter/foundation.dart';

/// BLE provisioning is available on mobile and desktop native targets, not web.
bool get isBleProvisioningSupported => !kIsWeb;

const String bleUnavailableWebMessage =
    'BLE-привязка недоступна в браузере — используйте телефон или десктоп-приложение';
