import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
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
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool? _loginAvailable;
  bool _checkingLogin = false;
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
    final login = _loginController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    final passwordError = validatePassword(password);
    if (passwordError != null) {
      _showError(passwordError);
      return;
    }
    if (password != confirm) {
      _showError('Пароли не совпадают');
      return;
    }
    if (_loginAvailable == false) {
      _showError('Логин уже занят');
      return;
    }

    await ref.read(authProvider.notifier).register(login, password);
    final error = ref.read(authProvider).error;
    if (error != null && mounted) {
      _showError(friendlyApiError(error));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    String? loginHelper;
    if (_checkingLogin) {
      loginHelper = 'Проверка…';
    } else if (_loginAvailable == true) {
      loginHelper = 'Логин свободен';
    } else if (_loginAvailable == false) {
      loginHelper = 'Логин занят';
    }

    return AuthScaffold(
      title: 'Регистрация',
      subtitle: 'Новый пользователь получает права viewer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _loginController,
            decoration: InputDecoration(
              labelText: 'Логин',
              helperText: loginHelper,
              suffixIcon: _loginAvailable == true
                  ? const Icon(Icons.check_circle_outline, color: TekColors.success)
                  : _loginAvailable == false
                      ? const Icon(Icons.cancel_outlined, color: TekColors.error)
                      : null,
            ),
            onChanged: (value) => _scheduleLoginCheck(value.trim()),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Пароль',
              helperText: '8+ символов, цифры и латиница',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            obscureText: _obscure,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            decoration: const InputDecoration(labelText: 'Подтверждение пароля'),
            obscureText: _obscure,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: auth.isLoading ? null : _submit,
            child: auth.isLoading
                ? const TekLoadingIndicator(size: 24, compact: true)
                : const Text('Зарегистрироваться'),
          ),
        ],
      ),
      footer: TextButton(
        onPressed: () => context.go('/login'),
        child: const Text('Уже есть аккаунт? Войти'),
      ),
    );
  }
}
