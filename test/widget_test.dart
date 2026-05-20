import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dwldr/main.dart';
import 'package:dwldr/core/providers.dart';

void main() {
  testWidgets('dwldr app smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
        ],
        child: const DwldrApp(),
      ),
    );
    // Use a longer timeout or pumpAndSettle if there are animations
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
