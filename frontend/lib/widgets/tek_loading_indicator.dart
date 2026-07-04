import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/theme/app_theme.dart';
import 'package:tek_sensor_monitor/core/theme/color_tokens.dart';

/// Branded loading indicator — oscilloscope-style waveform pulse.
class TekLoadingIndicator extends ConsumerStatefulWidget {
  const TekLoadingIndicator({
    super.key,
    this.size = 48,
    this.message,
    this.compact = false,
  });

  final double size;
  final String? message;
  final bool compact;

  @override
  ConsumerState<TekLoadingIndicator> createState() =>
      _TekLoadingIndicatorState();
}

class _TekLoadingIndicatorState extends ConsumerState<TekLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final animate = tekAnimationsEnabled(context, ref);

    if (!animate) {
      return _body(theme, 0.5);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => _body(theme, _controller.value),
    );
  }

  Widget _body(ThemeData theme, double t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size * 1.6,
          height: widget.size,
          child: CustomPaint(
            painter: _WaveformPainter(
              progress: t,
              color: theme.colorScheme.primary,
              glow: TekColors.primary.withValues(alpha: 0.25),
            ),
          ),
        ),
        if (widget.message != null) ...[
          SizedBox(height: widget.compact ? 8 : 16),
          Text(
            widget.message!,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.progress,
    required this.color,
    required this.glow,
  });

  final double progress;
  final Color color;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    const points = 40;
    for (var i = 0; i <= points; i++) {
      final x = size.width * i / points;
      final phase = (i / points + progress) * math.pi * 4;
      final y = size.height / 2 +
          math.sin(phase) * size.height * 0.28 +
          math.sin(phase * 2.3) * size.height * 0.08;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = glow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Full-page centered loader.
class TekPageLoading extends StatelessWidget {
  const TekPageLoading({super.key, this.message = 'Загрузка…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TekLoadingIndicator(size: 56, message: message),
    );
  }
}
