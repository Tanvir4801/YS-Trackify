import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic scaffold renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('YS Trackify')),
      ),
    );

    expect(find.text('YS Trackify'), findsOneWidget);
  });
}
