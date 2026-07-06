import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tek_sensor_monitor/core/api_config.dart';
import 'package:tek_sensor_monitor/core/api_url_provider.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
import 'package:tek_sensor_monitor/core/locale/locale_provider.dart';
import 'package:tek_sensor_monitor/core/password_validation.dart';
import 'package:tek_sensor_monitor/core/theme/app_theme.dart';
import 'package:tek_sensor_monitor/core/router.dart';
import 'package:tek_sensor_monitor/core/theme/color_tokens.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/settings/contact_verification_dialog.dart';
import 'package:tek_sensor_monitor/models/notification.dart';
import 'package:tek_sensor_monitor/models/user.dart';
import 'package:tek_sensor_monitor/widgets/tek_loading_indicator.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _passwordFormKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _serverUrlController = TextEditingController();
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _savingServerUrl = false;
  bool _initialized = false;
  bool _serverUrlInitialized = false;
  String? _passwordChangeSuccess;

  @override
  void dispose() {
    _loginController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  void _initFromProfile(UserProfile profile) {
    if (_initialized) return;
    _loginController.text = profile.login;
    _emailController.text = profile.email ?? '';
    _phoneController.text = profile.phone ?? '';
    _initialized = true;
  }

  void _initServerUrl(String baseUrl) {
    if (_serverUrlInitialized) return;
    _serverUrlController.text = baseUrl;
    _serverUrlInitialized = true;
  }

  Future<void> _saveServerUrl() async {
    final l10n = context.l10n;
    final code = validateApiBaseUrlInput(_serverUrlController.text);
    if (code != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorInvalidServerUrl)),
      );
      return;
    }

    setState(() => _savingServerUrl = true);
    try {
      await ref
          .read(apiBaseUrlProvider.notifier)
          .setUrl(_serverUrlController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.serverUrlSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e, l10n))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingServerUrl = false);
    }
  }

  Future<void> _saveProfile() async {
    final l10n = context.l10n;
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
            SnackBar(content: Text(sendResult.message ?? l10n.profileSaved)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e, l10n))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final l10n = context.l10n;
    if (!(_passwordFormKey.currentState?.validate() ?? false)) {
      return;
    }
    final newPassword = _newPasswordController.text;
    if (newPassword != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordsDoNotMatch)),
      );
      return;
    }

    setState(() {
      _savingPassword = true;
      _passwordChangeSuccess = null;
    });
    try {
      await ref.read(apiClientProvider).changePassword(
            currentPassword: _currentPasswordController.text,
            newPassword: newPassword,
          );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (mounted) {
        setState(() => _passwordChangeSuccess = l10n.passwordChanged);
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(l10n.passwordChanged)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e, l10n))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profileAsync = ref.watch(profileProvider);
    final baseUrl = ref.watch(apiBaseUrlProvider).valueOrNull;
    if (baseUrl != null) {
      _initServerUrl(baseUrl);
    }

    return profileAsync.when(
      loading: () => const TekPageLoading(),
      error: (e, _) => Center(child: Text(friendlyApiError(e, l10n))),
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
                    Text(l10n.profileTitle,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(l10n.roleLabel(profile.role),
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _loginController,
                      decoration: InputDecoration(
                        labelText: l10n.loginLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: l10n.emailLabel,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: l10n.phoneLabel,
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
                          : Text(l10n.saveProfile),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _passwordFormKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.changePasswordTitle,
                          style: Theme.of(context).textTheme.titleLarge),
                      if (_passwordChangeSuccess != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: TekColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: TekColors.success.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            _passwordChangeSuccess!,
                            style: const TextStyle(color: TekColors.success),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _currentPasswordController,
                        decoration: InputDecoration(
                          labelText: l10n.currentPasswordLabel,
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.errorPasswordRequired;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newPasswordController,
                        decoration: InputDecoration(
                          labelText: l10n.newPasswordLabel,
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.errorPasswordRequired;
                          }
                          return validatePassword(value, l10n);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: l10n.confirmPasswordFieldLabel,
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.errorPasswordRequired;
                          }
                          if (value != _newPasswordController.text) {
                            return l10n.passwordsDoNotMatch;
                          }
                          return null;
                        },
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
                            : Text(l10n.changePasswordButton),
                      ),
                    ],
                  ),
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
                    Text(l10n.appearanceTitle,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Consumer(
                      builder: (context, ref, _) {
                        final preference = ref.watch(themePreferenceProvider);
                        final themeL10n = context.l10n;
                        return SegmentedButton<AppThemePreference>(
                          segments: [
                            for (final mode in AppThemePreference.values)
                              ButtonSegment(
                                value: mode,
                                icon: Icon(mode.icon, size: 18),
                                label: Text(mode.label(themeL10n)),
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
                        final motionL10n = context.l10n;
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(motionL10n.reduceMotionTitle),
                          subtitle: Text(motionL10n.reduceMotionSubtitle),
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.languageTitle,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Consumer(
                      builder: (context, ref, _) {
                        final language = ref.watch(languagePreferenceProvider);
                        final langL10n = context.l10n;
                        return SegmentedButton<AppLanguage>(
                          segments: [
                            ButtonSegment(
                              value: AppLanguage.russian,
                              label: Text(langL10n.languageRussian),
                            ),
                            ButtonSegment(
                              value: AppLanguage.english,
                              label: Text(langL10n.languageEnglish),
                            ),
                          ],
                          selected: {language},
                          onSelectionChanged: (selected) {
                            ref
                                .read(languagePreferenceProvider.notifier)
                                .setLanguage(selected.first);
                          },
                        );
                      },
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
                    Text(l10n.serverUrlLabel,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      l10n.serverUrlHelper,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _serverUrlController,
                      decoration: InputDecoration(
                        labelText: l10n.serverUrlLabel,
                        hintText: apiBaseUrlPlaceholder,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      enableSuggestions: false,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _savingServerUrl ? null : _saveServerUrl,
                      child: _savingServerUrl
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.saveServerUrl),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _savingProfile || _savingPassword || _savingServerUrl
                  ? null
                  : () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
              icon: const Icon(Icons.logout),
              label: Text(l10n.signOutAccount),
            ),
          ],
        );
      },
    );
  }
}
