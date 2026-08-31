/// MCP diagnostic identity.
library;

import 'package:mcp_toolkit/mcp_toolkit.dart';

/// PromptLibrary application identity.
const mcpDiagnosticApplicationId = 'dev.hawkx.promptlibrary';

/// PromptLibrary diagnostic mode.
const mcpDiagnosticMode = 'mcp-diagnostic';

/// Diagnostic identity schema version.
const mcpDiagnosticSchemaVersion = 1;

/// Creates the identity extension entry.
MCPCallEntry createMcpDiagnosticIdentityEntry() {
  return MCPCallEntry.tool(
    handler: (parameters) {
      return MCPCallResult(
        message: 'PromptLibrary MCP diagnostic identity.',
        parameters: {
          'applicationId': mcpDiagnosticApplicationId,
          'mode': mcpDiagnosticMode,
          'schemaVersion': mcpDiagnosticSchemaVersion,
        },
      );
    },
    definition: MCPToolDefinition(
      name: 'prompt_library_identity',
      description: 'Identify the PromptLibrary MCP diagnostic process.',
      inputSchema: ObjectSchema(properties: {}),
    ),
  );
}

/// Registers the identity extension.
Future<void> registerMcpDiagnosticIdentity() {
  return MCPToolkitBinding.instance.addEntries(
    entries: {createMcpDiagnosticIdentityEntry()},
  );
}
