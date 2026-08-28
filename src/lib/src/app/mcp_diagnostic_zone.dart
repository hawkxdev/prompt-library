/// MCP diagnostic error zone.
library;

import 'dart:async';

/// Records a diagnostic zone error.
typedef McpDiagnosticErrorCapture = void Function(
  Object error,
  StackTrace stackTrace,
);

/// Runs diagnostics while forwarding errors.
void runMcpDiagnosticZone(
  Future<void> Function() body, {
  required McpDiagnosticErrorCapture capture,
}) {
  final future = runZonedGuarded<Future<void>>(body, (error, stackTrace) {
    capture(error, stackTrace);
    Error.throwWithStackTrace(error, stackTrace);
  });
  if (future != null) {
    unawaited(future);
  }
}
