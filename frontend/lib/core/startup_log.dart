import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Appends startup errors to a log file next to the executable (desktop/mobile).
Future<void> logStartupError(Object error, [StackTrace? stack]) async {
  if (kIsWeb) return;
  try {
    final exe = Platform.resolvedExecutable;
    final sep = Platform.pathSeparator;
    final dir = File(exe).parent.path;
    final logFile = File('$dir${sep}startup_errors.log');
    final entry = StringBuffer()
      ..writeln(DateTime.now().toIso8601String())
      ..writeln(error)
      ..writeln(stack ?? StackTrace.current)
      ..writeln('---');
    await logFile.writeAsString('$entry\n', mode: FileMode.append);
  } catch (_) {
    // Best-effort diagnostics only.
  }
}

Future<void> safeInit(
  String label,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error, stack) {
    await logStartupError('[$label] $error', stack);
  }
}
