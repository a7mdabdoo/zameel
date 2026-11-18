import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zameel/features/home/main_navigation_shell.dart';
import 'package:zameel/features/planner/presentation/today_screen.dart';
import 'package:zameel/features/auth/presentation/welcome_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zameel/main.dart';

void main() {
  testWidgets('Renders ZameelApp without localization error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ZameelApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('Renders MainNavigationShell and NavigationBar with Arabic locale via ZameelApp delegates', (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainNavigationShell(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/today', builder: (context, state) => const TodayScreen()),
              ],
              
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            final app = const ZameelApp();
            final materialApp = app.build(context, ref) as MaterialApp;
            return MaterialApp.router(
              routerConfig: router,
              locale: const Locale('ar'),
              supportedLocales: materialApp.supportedLocales,
              localizationsDelegates: materialApp.localizationsDelegates,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
