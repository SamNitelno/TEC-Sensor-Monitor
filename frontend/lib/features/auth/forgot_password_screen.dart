import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
import 'package:tek_sensor_monitor/core/password_validation.dart';
import 'package:tek_sensor_monitor/core/router.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/l10n/app_localizations.dart';
import 'package:tek_sensor_monitor/widgets/auth_scaffold.dart';
import 'package:tek_sensor_monitor/widgets/tek_loading_indicator.dart';

enum _ForgotStep { request, confirm }

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  _ForgotStep _step = _ForgotStep.request;
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _usePhone = false;
  bool _busy = false;
  String? _batchId;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.requestPasswordReset(
        email: _usePhone ? null : _emailController.text.trim(),
        phone: _usePhone ? _phoneController.text.trim() : null,
      );
      setState(() {
        _batchId = result.batchId;
        _step = _ForgotStep.confirm;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e, l10n))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReset() async {
    final l10n = context.l10n;
    final batchId = _batchId;
    if (batchId == null) return;

    final password = _passwordController.text;
    if (password != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordsDoNotMatch)),
      );
      return;
    }
    final validation = validatePassword(password, l10n);
    if (validation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation)),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).confirmPasswordReset(
            batchId: batchId,
            code: _codeController.text.trim(),
            newPassword: password,
          );
      if (!mounted) return;
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(l10n.passwordResetSuccess)),
      );
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e, l10n))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AuthScaffold(
      title: l10n.forgotPasswordTitle,
      subtitle: _step == _ForgotStep.request
          ? l10n.forgotPasswordSubtitle
          : l10n.resetPasswordTitle,
      child: _step == _ForgotStep.request ? _buildRequest(l10n) : _buildConfirm(l10n),
      footer: TextButton(
        onPressed: () => context.go('/login'),
        child: Text(l10n.hasAccountLogin),
      ),
    );
  }

  Widget _buildRequest(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l10n.emailLabel)),
            ButtonSegment(value: true, label: Text(l10n.phoneLabel)),
          ],
          selected: {_usePhone},
          onSelectionChanged: (value) => setState(() => _usePhone = value.first),
        ),
        const SizedBox(height: 16),
        if (_usePhone)
          TextField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: l10n.phoneLabel,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          )
        else
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: l10n.emailLabel,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _requestCode,
          child: _busy
              ? const TekLoadingIndicator(size: 24, compact: true)
              : Text(l10n.sendResetCode),
        ),
      ],
    );
  }

  Widget _buildConfirm(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _codeController,
          decoration: InputDecoration(
            labelText: l10n.emailCodeHint,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: l10n.newPasswordLabel,
            border: const OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmController,
          decoration: InputDecoration(
            labelText: l10n.confirmPasswordFieldLabel,
            border: const OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _confirmReset,
          child: _busy
              ? const TekLoadingIndicator(size: 24, compact: true)
              : Text(l10n.resetPasswordButton),
        ),
      ],
    );
  }
}
