import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skilloper_app/main.dart';

void main() {
  testWidgets('Skilloper app can be instantiated', (WidgetTester tester) async {
    await tester.pumpWidget(const SkiloperApp());

    // App builds without error and shows loading indicator initially
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
