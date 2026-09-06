import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatbox/main.dart';

void main() {
  testWidgets('ChatScreen smoke test and message sending verification',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify header components
    expect(find.text('Twilight'), findsOneWidget);
    expect(find.text('💕 Send luv'), findsOneWidget);

    // Verify input field exists
    expect(find.text('Type a message...'), findsOneWidget);

    // Verify initial mock messages and date grouping
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Hey! How was your day? 😊'), findsOneWidget);

    // Test sending a new message
    const testMessage = 'Hello from automated test!';
    await tester.enterText(find.byType(TextField), testMessage);
    await tester.pump();

    // Tap the send button
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    // Verify the new message appears in the chat list
    expect(find.text(testMessage), findsOneWidget);

    // Verify the input field was cleared
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, isEmpty);

    // Test "Send luv" button interaction
    await tester.tap(find.text('💕 Send luv'));
    await tester.pump(); // Start SnackBar animation
    expect(find.text('💕 Love sent!'), findsOneWidget);

    // Let any pending timers and animations finish cleanly
    await tester.pump(const Duration(seconds: 3));
  });
}
