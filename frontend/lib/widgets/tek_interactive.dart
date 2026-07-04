import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/theme/app_theme.dart';
import 'package:tek_sensor_monitor/core/theme/color_tokens.dart';

/// Subtle press/hover feedback without layout shift.
class TekInteractive extends ConsumerStatefulWidget {
  const TekInteractive({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final bool enabled;

  @override
  ConsumerState<TekInteractive> createState() => _TekInteractiveState();
}

class _TekInteractiveState extends ConsumerState<TekInteractive> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final animate = tekAnimationsEnabled(context, ref);
    final scale = !animate || !widget.enabled
        ? 1.0
        : _pressed
            ? 0.98
            : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: scale,
          duration: animate ? const Duration(milliseconds: 120) : Duration.zero,
          child: AnimatedContainer(
            duration: animate ? const Duration(milliseconds: 180) : Duration.zero,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              color: _hovered && widget.enabled
                  ? theme.colorScheme.primary.withValues(alpha: 0.06)
                  : Colors.transparent,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class LivePulseDot extends ConsumerStatefulWidget {
  const LivePulseDot({super.key, this.size = 8});

  final double size;

  @override
  ConsumerState<LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends ConsumerState<LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = tekAnimationsEnabled(context, ref);
    final color = TekColors.success;

    if (!animate) {
      return _dot(color, 1);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => _dot(color, 0.5 + _controller.value * 0.5),
    );
  }

  Widget _dot(Color color, double opacity) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: opacity * 0.5),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}
