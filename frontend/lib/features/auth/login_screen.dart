import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
import 'package:tek_sensor_monitor/core/theme/color_tokens.dart';
import 'package:tek_sensor_monitor/core/api_url_provider.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/widgets/auth_scaffold.dart';
import 'package:tek_sensor_monitor/widgets/tek_loading_indicator.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _loginController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final l10n = context.l10n;
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _errorMessage = l10n.errorPasswordRequired);
      return;
    }

    _isSubmitting = true;
    setState(() => _errorMessage = null);

    try {
      await ref.read(authProvider.notifier).login(
            _loginController.text.trim(),
            password,
          );
      if (!mounted) return;
      final authState = ref.read(authProvider);
      if (authState.hasError) {
        final serverUrl = ref.read(apiBaseUrlProvider).valueOrNull;
        setState(() {
          _errorMessage = friendlyApiError(
            authState.error!,
            l10n,
            serverUrl: serverUrl,
          );
        });
      }
    } finally {
      _isSubmitting = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showForgotPassword = ref.watch(authCapabilitiesProvider).maybeWhen(
          data: (c) => c.passwordReset,
          orElse: () => true,
        );

    return AuthScaffold(
      title: l10n.appTitleShort,
      subtitle: l10n.loginTitle,
      footer: TextButton(
        onPressed: _isSubmitting ? null : () => context.go('/register'),
        child: Text(l10n.noAccountRegister),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TekColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: TekColors.error.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _loginController,
            decoration: InputDecoration(labelText: l10n.loginLabel),
            textInputAction: TextInputAction.next,
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: l10n.passwordLabel,
              helperText: l10n.passwordHelper,
              helperMaxLines: 2,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            obscureText: _obscure,
            enabled: !_isSubmitting,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_isSubmitting) _submit();
            },
          ),
          if (showForgotPassword) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed:
                    _isSubmitting ? null : () => context.go('/forgot-password'),
                child: Text(l10n.forgotPassword),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const TekLoadingIndicator(size: 24, compact: true)
                : Text(l10n.signIn),
          ),
        ],
      ),
    );
  }
}
