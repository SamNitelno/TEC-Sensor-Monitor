import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/core/password_validation.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/settings/contact_verification_dialog.dart';
import 'package:tek_sensor_monitor/models/notification.dart';
import 'package:tek_sensor_monitor/models/user.dart';
import 'package:tek_sensor_monitor/core/theme/app_theme.dart';
import 'package:tek_sensor_monitor/widgets/tek_loading_indicator.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _loginController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _initialized = false;

  @override
  void dispose() {
    _loginController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _initFromProfile(UserProfile profile) {
    if (_initialized) return;
    _loginController.text = profile.login;
    _emailController.text = profile.email ?? '';
    _phoneController.text = profile.phone ?? '';
    _initialized = true;
  }

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    try {
      final api = ref.read(apiClientProvider);
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();

      final sendResult = await api.sendContactVerificationCodes(
        login: _loginController.text.trim(),
        email: email.isEmpty ? null : email,
        clearEmail: email.isEmpty,
        phone: phone.isEmpty ? null : phone,
        clearPhone: phone.isEmpty,
      );

      ProfileUpdateResult? updateResult;
      if (sendResult.step == 'complete' && sendResult.profile != null) {
        updateResult = ProfileUpdateResult(
          profile: sendResult.profile!,
          accessToken: sendResult.accessToken,
        );
      } else if (mounted) {
        updateResult = await ContactVerificationDialog.show(
          context,
          api: api,
          start: sendResult,
        );
      }

      if (updateResult != null) {
        await ref.read(authProvider.notifier).applyProfileUpdate(updateResult);
        ref.invalidate(profileProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sendResult.message ?? 'Профиль сохранён')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final newPassword = _newPasswordController.text;
    final passwordError = validatePassword(newPassword);
    if (passwordError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(passwordError)),
      );
      return;
    }
    if (newPassword != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароли не совпадают')),
      );
      return;
    }

    setState(() => _savingPassword = true);
    try {
      await ref.read(apiClientProvider).changePassword(
            currentPassword: _currentPasswordController.text,
            newPassword: newPassword,
          );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пароль изменён')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      loading: () => const TekPageLoading(),
      error: (e, _) => Center(child: Text(friendlyApiError(e))),
      data: (profile) {
        _initFromProfile(profile);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Профиль', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text('Роль: ${profile.role}', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _loginController,
                      decoration: const InputDecoration(
                        labelText: 'Логин',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        helperText:
                            'При изменении придёт код подтверждения на почту',
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Телефон',
                        helperText:
                            'После email (если меняете оба) — код в SMS',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _savingProfile ? null : _saveProfile,
                      child: _savingProfile
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Сохранить профиль'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Смена пароля', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _currentPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Текущий пароль',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Новый пароль',
                        border: OutlineInputBorder(),
                        helperText: '8+ символов, цифры и латиница',
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Подтверждение',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _savingPassword ? null : _changePassword,
                      child: _savingPassword
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Сменить пароль'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Оформление', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Consumer(
                      builder: (context, ref, _) {
                        final preference = ref.watch(themePreferenceProvider);
                        return SegmentedButton<AppThemePreference>(
                          segments: [
                            for (final mode in AppThemePreference.values)
                              ButtonSegment(
                                value: mode,
                                icon: Icon(mode.icon, size: 18),
                                label: Text(mode.label),
                              ),
                          ],
                          selected: {preference},
                          onSelectionChanged: (selected) {
                            ref
                                .read(themePreferenceProvider.notifier)
                                .setPreference(selected.first);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Consumer(
                      builder: (context, ref, _) {
                        final reduceMotion = ref.watch(reduceMotionProvider);
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Уменьшить анимации'),
                          subtitle: const Text(
                            'Отключает эффекты интерфейса и графиков',
                          ),
                          value: reduceMotion,
                          onChanged: (value) => ref
                              .read(reduceMotionProvider.notifier)
                              .setEnabled(value),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('Выйти из аккаунта'),
            ),
          ],
        );
      },
    );
  }
}
