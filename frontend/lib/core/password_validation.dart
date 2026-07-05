import 'package:tek_sensor_monitor/l10n/app_localizations.dart';

String? validatePassword(String password, AppLocalizations l10n) {
  if (password.length < 8) {
    return l10n.passwordMinLength;
  }
  if (!RegExp(r'[0-9]').hasMatch(password)) {
    return l10n.passwordNeedsDigit;
  }
  if (!RegExp(r'[A-Za-z]').hasMatch(password)) {
    return l10n.passwordNeedsLatin;
  }
  return null;
}
