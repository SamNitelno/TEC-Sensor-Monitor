import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tek_sensor_monitor/core/api_client.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/models/contact_verification.dart';
import 'package:tek_sensor_monitor/models/notification.dart';

class ContactVerificationDialog extends StatefulWidget {
  const ContactVerificationDialog({
    super.key,
    required this.api,
    required this.initialStep,
    required this.batchId,
    required this.destinationMasked,
  });

  final ApiClient api;
  final String initialStep;
  final String batchId;
  final String? destinationMasked;

  static Future<ProfileUpdateResult?> show(
    BuildContext context, {
    required ApiClient api,
    required ContactSendCodesResult start,
  }) {
    if (start.step == 'complete') {
      if (start.profile != null) {
        return Future.value(
          ProfileUpdateResult(
            profile: start.profile!,
            accessToken: start.accessToken,
          ),
        );
      }
      return Future.value(null);
    }

    return showDialog<ProfileUpdateResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ContactVerificationDialog(
        api: api,
        initialStep: start.step,
        batchId: start.batchId,
        destinationMasked: start.destinationMasked,
      ),
    );
  }

  @override
  State<ContactVerificationDialog> createState() =>
      _ContactVerificationDialogState();
}

class _ContactVerificationDialogState extends State<ContactVerificationDialog> {
  late String _step;
  late String _batchId;
  String? _destinationMasked;
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep;
    _batchId = widget.batchId;
    _destinationMasked = widget.destinationMasked;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Введите код из письма или SMS');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_step == 'email') {
        final result = await widget.api.verifyContactEmail(
          batchId: _batchId,
          code: code,
        );
        if (!mounted) return;
        if (result.step == 'complete' && result.profile != null) {
          Navigator.pop(
            context,
            ProfileUpdateResult(
              profile: result.profile!,
              accessToken: result.accessToken,
            ),
          );
          return;
        }
        setState(() {
          _step = result.step;
          _destinationMasked = result.destinationMasked;
          _codeController.clear();
          _submitting = false;
        });
        return;
      }

      final result = await widget.api.verifyContactPhone(
        batchId: _batchId,
        code: code,
      );
      if (!mounted) return;
      if (result.profile != null) {
        Navigator.pop(
          context,
          ProfileUpdateResult(
            profile: result.profile!,
            accessToken: result.accessToken,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyApiError(e);
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmail = _step == 'email';
    final title = isEmail ? 'Подтверждение email' : 'Подтверждение телефона';
    final hint = isEmail
        ? 'Введите код из письма'
        : 'Введите код из SMS';

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_destinationMasked != null)
            Text(
              'Код отправлен на $_destinationMasked',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            decoration: InputDecoration(
              labelText: hint,
              errorText: _error,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            autofocus: true,
            onSubmitted: (_) => _submitting ? null : _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Подтвердить'),
        ),
      ],
    );
  }
}
