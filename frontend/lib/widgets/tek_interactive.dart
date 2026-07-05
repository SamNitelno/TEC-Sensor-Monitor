import 'package:flutter/foundation.dart';
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
    final duration = TekMotion.microDuration(animate: animate);
    final scale = !animate || !widget.enabled
        ? 1.0
        : _pressed
            ? 0.98
            : 1.0;
    final hoverColor = _hovered && widget.enabled
        ? theme.colorScheme.primary.withValues(alpha: 0.06)
        : Colors.transparent;

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
          duration: duration,
          curve: Curves.easeOutCubic,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              color: hoverColor,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class LivePulseDot extends ConsumerWidget {
  const LivePulseDot({super.key, this.size = 8});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animate = tekAnimationsEnabled(context, ref) && !kIsWeb;
    if (!animate) {
      return _LivePulseDotBody(size: size, opacity: 1);
    }
    return _AnimatedLivePulseDot(size: size);
  }
}

class _AnimatedLivePulseDot extends StatefulWidget {
  const _AnimatedLivePulseDot({required this.size});

  final double size;

  @override
  State<_AnimatedLivePulseDot> createState() => _AnimatedLivePulseDotState();
}

class _AnimatedLivePulseDotState extends State<_AnimatedLivePulseDot>
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => _LivePulseDotBody(
        size: widget.size,
        opacity: 0.5 + _controller.value * 0.5,
      ),
    );
  }
}

class _LivePulseDotBody extends StatelessWidget {
  const _LivePulseDotBody({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final color = TekColors.success;
    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
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
      ),
    );
  }
}
