import 'package:flutter/material.dart';

class TekLogo extends StatelessWidget {
  const TekLogo({
    super.key,
    this.height = 36,
    this.showAlt = false,
  });

  final double height;
  final bool showAlt;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.asset(
        showAlt
            ? 'assets/images/logo_tec_alt.jpg'
            : 'assets/images/logo_tec.jpg',
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.electric_bolt,
          size: height,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
