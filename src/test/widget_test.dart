/// Shell contract tests. Literal strings keep asserts falsifiable.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:prompt_library/src/app/prompt_library_app.dart';

void main() {
  testWidgets('shell shows the title and the empty library message', (
    tester,
  ) async {
    await tester.pumpWidget(const PromptLibraryApp());

    expect(find.text('Prompt Library'), findsOneWidget);
    expect(find.text('Your library is empty'), findsOneWidget);
  });
}
