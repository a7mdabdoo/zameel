import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zameel/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ZameelApp(),
      ),
    );

    // Initial check
    expect(find.byType(ZameelApp), findsOneWidget);
  });
}
