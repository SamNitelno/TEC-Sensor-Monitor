import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Themed scrollbars for web/desktop; thumb always visible on wide screens.
class TekScrollBehavior extends MaterialScrollBehavior {
  const TekScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: true,
      trackVisibility: true,
      child: child,
    );
  }
}
