import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starboy_analytica/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app renders
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  // Add more widget tests here as needed
  // Example: Test login screen, test subscription page, etc.
}

