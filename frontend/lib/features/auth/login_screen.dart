import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
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

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    await ref.read(authProvider.notifier).login(
          _loginController.text.trim(),
          _passwordController.text,
        );
    final error = ref.read(authProvider).error;
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loginError(error.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final l10n = context.l10n;

    return AuthScaffold(
      title: l10n.appTitleShort,
      subtitle: l10n.loginTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _loginController,
            decoration: InputDecoration(labelText: l10n.loginLabel),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: l10n.passwordLabel,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            obscureText: _obscure,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: auth.isLoading ? null : _submit,
            child: auth.isLoading
                ? const TekLoadingIndicator(size: 24, compact: true)
                : Text(l10n.signIn),
          ),
        ],
      ),
      footer: TextButton(
        onPressed: () => context.go('/register'),
        child: Text(l10n.noAccountRegister),
      ),
    );
  }
}
