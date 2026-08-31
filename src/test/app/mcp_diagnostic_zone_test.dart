/// MCP diagnostic zone tests.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/app/mcp_diagnostic_zone.dart';

void main() {
  test('captures and forwards the original asynchronous error', () async {
    final error = StateError('zone failure');
    final originalStack = StackTrace.current;
    Object? capturedError;
    StackTrace? capturedStack;
    final forwarded = Completer<(Object, StackTrace)>();

    runZonedGuarded(
      () {
        runMcpDiagnosticZone(
          () async {
            await Future<void>.delayed(Duration.zero);
            Error.throwWithStackTrace(error, originalStack);
          },
          capture: (caughtError, caughtStack) {
            capturedError = caughtError;
            capturedStack = caughtStack;
          },
        );
      },
      (caughtError, caughtStack) {
        forwarded.complete((caughtError, caughtStack));
      },
    );

    final (forwardedError, forwardedStack) = await forwarded.future.timeout(
      const Duration(seconds: 1),
    );
    expect(identical(capturedError, error), isTrue);
    expect(identical(forwardedError, error), isTrue);
    expect(capturedStack.toString(), originalStack.toString());
    expect(forwardedStack.toString(), originalStack.toString());
  });
}
