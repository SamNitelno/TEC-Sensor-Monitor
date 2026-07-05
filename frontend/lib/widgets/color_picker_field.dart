import 'package:flutter/material.dart';
import 'package:tek_sensor_monitor/core/color_utils.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';

class ColorPickerField extends StatefulWidget {
  const ColorPickerField({
    super.key,
    required this.label,
    this.value,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  State<ColorPickerField> createState() => _ColorPickerFieldState();
}

class _ColorPickerFieldState extends State<ColorPickerField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(ColorPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final borderColor = theme.dividerColor;
    final parsed = parseHexColor(_controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < presetColors.length; i++)
              _ColorSwatch(
                color: parseHexColor(presetColors[i])!,
                selected: _controller.text.toUpperCase() == presetColors[i],
                onTap: () {
                  _controller.text = presetColors[i];
                  widget.onChanged(presetColors[i]);
                  setState(() {});
                },
              ),
            _ColorSwatch(
              color: Colors.transparent,
              selected: _controller.text.isEmpty,
              onTap: () {
                _controller.clear();
                widget.onChanged(null);
                setState(() {});
              },
              icon: Icons.block,
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: l10n.hexColorFormat,
            prefixIcon: parsed != null
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: parsed,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor),
                      ),
                    ),
                  )
                : null,
            errorText: validateHexColor(
              _controller.text.isEmpty ? null : _controller.text,
              l10n,
            ),
          ),
          onChanged: (value) {
            final trimmed = value.trim();
            if (trimmed.isEmpty) {
              widget.onChanged(null);
            } else if (validateHexColor(trimmed, l10n) == null) {
              widget.onChanged(trimmed.toUpperCase());
            }
            setState(() {});
          },
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: icon == null ? color : Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 3 : 1,
          ),
        ),
        child: icon != null
            ? Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            : null,
      ),
    );
  }
}
