import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
import 'package:tek_sensor_monitor/core/password_validation.dart';
import 'package:tek_sensor_monitor/core/theme/color_tokens.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/widgets/auth_scaffold.dart';
import 'package:tek_sensor_monitor/widgets/tek_loading_indicator.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool? _loginAvailable;
  bool _checkingLogin = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _loginController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _scheduleLoginCheck(String login) {
    _debounce?.cancel();
    if (login.length < 3) {
      setState(() {
        _loginAvailable = null;
        _checkingLogin = false;
      });
      return;
    }
    setState(() => _checkingLogin = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final available = await ref
            .read(rawApiClientProvider)
            .checkLoginAvailable(login);
        if (mounted && _loginController.text.trim() == login) {
          setState(() {
            _loginAvailable = available;
            _checkingLogin = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _checkingLogin = false);
      }
    });
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final login = _loginController.text.trim();
    final password = _passwordController.text;
    if (_loginAvailable == false) {
      setState(() => _errorMessage = l10n.loginAlreadyTaken);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authProvider.notifier).register(login, password);
      if (!mounted) return;
      final authState = ref.read(authProvider);
      if (authState.hasError) {
        setState(() {
          _errorMessage = friendlyApiError(authState.error!, l10n);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    String? loginHelper;
    if (_checkingLogin) {
      loginHelper = l10n.checking;
    } else if (_loginAvailable == true) {
      loginHelper = l10n.loginAvailable;
    } else if (_loginAvailable == false) {
      loginHelper = l10n.loginTaken;
    }

    return AuthScaffold(
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TekColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: TekColors.error.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _loginController,
              decoration: InputDecoration(
                labelText: l10n.loginLabel,
                helperText: loginHelper,
                suffixIcon: _loginAvailable == true
                    ? const Icon(Icons.check_circle_outline, color: TekColors.success)
                    : _loginAvailable == false
                        ? const Icon(Icons.cancel_outlined, color: TekColors.error)
                        : null,
              ),
              onChanged: (value) => _scheduleLoginCheck(value.trim()),
              textInputAction: TextInputAction.next,
              enabled: !_isSubmitting,
              validator: (value) {
                final login = value?.trim() ?? '';
                if (login.length < 3) {
                  return l10n.loginMinLength;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: l10n.passwordLabel,
                helperText: l10n.passwordHelper,
                helperMaxLines: 2,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              obscureText: _obscure,
              enabled: !_isSubmitting,
              validator: (value) => validatePassword(value ?? '', l10n),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              decoration: InputDecoration(
                labelText: l10n.confirmPasswordLabel,
              ),
              obscureText: _obscure,
              enabled: !_isSubmitting,
              validator: (value) {
                if (value != _passwordController.text) {
                  return l10n.passwordsDoNotMatch;
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const TekLoadingIndicator(size: 24, compact: true)
                  : Text(l10n.registerButton),
            ),
          ],
        ),
      ),
      footer: TextButton(
        onPressed: _isSubmitting ? null : () => context.go('/login'),
        child: Text(l10n.hasAccountLogin),
      ),
    );
  }
}
