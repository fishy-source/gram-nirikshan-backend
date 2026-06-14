// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:gram_nirikshan/main.dart';

void main() {
  testWidgets('GeminiApp loads successfully smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GeminiApp());

    // Verify that the main title exists.
    expect(find.text('Gemini Workspace'), findsOneWidget);
    
    // Verify that the prompt input hint is displayed.
    expect(find.text('Ask Gemini Pro anything...'), findsOneWidget);
  });
}

