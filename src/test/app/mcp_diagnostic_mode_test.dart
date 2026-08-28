/// MCP diagnostic mode tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/app/mcp_diagnostic_mode.dart';

void main() {
  test('allows debug mode', () {
    expect(
      () => ensureMcpDiagnosticDebugMode(debugMode: true),
      returnsNormally,
    );
  });

  test('terminates non-debug mode with a usage error', () {
    int? exitCode;

    expect(
      () => ensureMcpDiagnosticDebugMode(
        debugMode: false,
        terminate: (value) {
          exitCode = value;
          throw const _Termination();
        },
      ),
      throwsA(isA<_Termination>()),
    );
    expect(exitCode, 64);
  });
}

final class _Termination implements Exception {
  const _Termination();
}
