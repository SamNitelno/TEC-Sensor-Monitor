import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/core/password_validation.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';

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
        if (mounted) {
          setState(() => _checkingLogin = false);
        }
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
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);

    String? loginHelper;
    if (_checkingLogin) {
      loginHelper = 'Проверка…';
    } else if (_loginAvailable == true) {
      loginHelper = 'Логин свободен';
    } else if (_loginAvailable == false) {
      loginHelper = 'Логин занят';
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                  Icon(Icons.person_add, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Регистрация',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Новый пользователь получает права viewer',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _loginController,
                    decoration: InputDecoration(
                      labelText: 'Логин',
                      border: const OutlineInputBorder(),
                      helperText: loginHelper,
                      suffixIcon: _loginAvailable == true
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : _loginAvailable == false
                              ? const Icon(Icons.cancel, color: Colors.red)
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
                      border: const OutlineInputBorder(),
                      helperText: '8+ символов, цифры и латиница',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    obscureText: _obscure,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmController,
                    decoration: const InputDecoration(
                      labelText: 'Подтверждение пароля',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: _obscure,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: auth.isLoading ? null : _submit,
                    child: auth.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Зарегистрироваться'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Уже есть аккаунт? Войти'),
                  ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
