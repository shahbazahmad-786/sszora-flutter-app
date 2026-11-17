import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ssz_ora_flutter/core/api.dart';
import 'package:ssz_ora_flutter/core/theme.dart';
import 'package:ssz_ora_flutter/screens/shop_screen.dart';
import 'package:ssz_ora_flutter/state/app_state.dart';

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

  testWidgets('a standalone shop screen has its own scaffold', (tester) async {
    final state = AppState(_ShopTestApi());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: ShopScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shop'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });
}

class _ShopTestApi extends ApiClient {
  _ShopTestApi() : super(baseUrl: 'https://example.test', deviceId: 'test');

  @override
  Future<dynamic> get(String path, [Map<String, dynamic>? query]) async {
    return {
      'products': {
        'data': <dynamic>[],
        'meta': {'total': 0, 'current_page': 1, 'last_page': 1},
      },
    };
  }
}
