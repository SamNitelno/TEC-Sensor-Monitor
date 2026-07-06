import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tek_sensor_monitor/core/local_notifications.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/main.dart';
import 'package:tek_sensor_monitor/models/auth_capabilities.dart';
import 'package:tek_sensor_monitor/models/auth_session.dart';

class _LoggedOutAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await LocalNotifications.init();
  });

  testWidgets('Login screen shows credentials form', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_LoggedOutAuthNotifier.new),
          authBootstrappedProvider.overrideWith((ref) => true),
          authCapabilitiesProvider.overrideWith(
            (ref) async => const AuthCapabilities(
              publicRegistration: true,
              passwordReset: false,
            ),
          ),
        ],
        child: const TekSensorMonitorApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    final signIn = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.data == 'Войти' || widget.data == 'Sign in'),
    );
    expect(signIn, findsOneWidget);
  });
}
