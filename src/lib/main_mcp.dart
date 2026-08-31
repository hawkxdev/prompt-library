/// MCP diagnostic entry point.
library;

import 'package:flutter/widgets.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

import 'package:prompt_library/src/app/composition_root.dart';
import 'package:prompt_library/src/app/mcp_diagnostic_composition.dart';
import 'package:prompt_library/src/app/mcp_diagnostic_identity.dart';
import 'package:prompt_library/src/app/mcp_diagnostic_mode.dart';
import 'package:prompt_library/src/app/mcp_diagnostic_zone.dart';

/// Starts isolated MCP diagnostics.
void main() {
  ensureMcpDiagnosticDebugMode();
  runMcpDiagnosticZone(() async {
    WidgetsFlutterBinding.ensureInitialized();
    MCPToolkitBinding.instance
      ..initialize()
      ..initializeFlutterToolkit();
    await registerMcpDiagnosticIdentity();
    final composition = await createMcpDiagnosticComposition();
    runApp(PromptLibraryCompositionRoot(composition: composition));
  }, capture: MCPToolkitBinding.instance.handleZoneError);
}
