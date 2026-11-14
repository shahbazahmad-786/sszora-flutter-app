import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssz_ora_flutter/core/theme.dart';

void main() {
  testWidgets('SSZora theme renders the store name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Text('SSZora')),
      ),
    );

    expect(find.text('SSZora'), findsOneWidget);
  });
}
