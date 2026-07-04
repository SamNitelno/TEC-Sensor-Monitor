import 'package:flutter/material.dart';
import 'package:tek_sensor_monitor/core/color_utils.dart';

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
    final parsed = parseHexColor(_controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
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
            labelText: 'HEX (#RRGGBB)',
            border: const OutlineInputBorder(),
            prefixIcon: parsed != null
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: parsed,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                  )
                : null,
            errorText: validateHexColor(
              _controller.text.isEmpty ? null : _controller.text,
            ),
          ),
          onChanged: (value) {
            final trimmed = value.trim();
            if (trimmed.isEmpty) {
              widget.onChanged(null);
            } else if (validateHexColor(trimmed) == null) {
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
          color: icon == null ? color : Colors.grey.shade200,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.grey,
            width: selected ? 3 : 1,
          ),
        ),
        child: icon != null ? Icon(icon, size: 18) : null,
      ),
    );
  }
}
