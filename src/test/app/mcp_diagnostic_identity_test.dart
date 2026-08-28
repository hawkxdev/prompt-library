/// MCP diagnostic identity tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/app/mcp_diagnostic_identity.dart';

void main() {
  test('publishes the PromptLibrary diagnostic identity', () async {
    final entry = createMcpDiagnosticIdentityEntry();
    final result = await entry.value.handler(const {});

    expect(entry.key, 'prompt_library_identity');
    expect(result['applicationId'], 'dev.hawkx.promptlibrary');
    expect(result['mode'], 'mcp-diagnostic');
    expect(result['schemaVersion'], 1);
  });
}
