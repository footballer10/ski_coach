import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ski_coach/config/ai_config.dart';
import 'package:ski_coach/widgets/api_key_dialog.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AIPreferences.load();
  });

  Future<void> openDialog(WidgetTester tester, List<bool?> result) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result.add(await showApiKeyDialog(context)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('saving a key stores it and closes cleanly', (tester) async {
    final result = <bool?>[];
    await openDialog(tester, result);

    await tester.enterText(find.byType(TextField), '  sk-test  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(result, [true]);
    expect(AIPreferences.apiKey, 'sk-test');
  });

  testWidgets('cancelling after typing saves nothing', (tester) async {
    final result = <bool?>[];
    await openDialog(tester, result);

    await tester.enterText(find.byType(TextField), 'sk-test');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(result, [false]);
    expect(AIPreferences.hasApiKey, isFalse);
  });

  testWidgets('remove key clears a saved key', (tester) async {
    await AIPreferences.setApiKey('sk-old');
    final result = <bool?>[];
    await openDialog(tester, result);

    await tester.tap(find.text('Remove key'));
    await tester.pumpAndSettle();

    expect(result, [false]);
    expect(AIPreferences.hasApiKey, isFalse);
  });
}
