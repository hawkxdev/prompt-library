/// MCP diagnostic build mode.
library;

import 'dart:io' as io;

import 'package:flutter/foundation.dart';

/// Terminates an invalid diagnostic process.
typedef McpDiagnosticTerminate = Never Function(int exitCode);

/// Rejects non-debug diagnostic launches.
void ensureMcpDiagnosticDebugMode({
  bool debugMode = kDebugMode,
  McpDiagnosticTerminate terminate = io.exit,
}) {
  if (!debugMode) {
    io.stderr.writeln('MCP diagnostics require a Debug build.');
    terminate(64);
  }
}
