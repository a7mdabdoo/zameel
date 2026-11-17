import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zameel/core/l10n/app_localizations.dart';
import 'package:zameel/features/home/main_navigation_shell.dart';
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

  testWidgets('Renders MainNavigationShell and NavigationBar with Arabic locale', (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainNavigationShell(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/', builder: (context, state) => const Text('Branch 0')),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/1', builder: (context, state) => const Text('Branch 1')),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/2', builder: (context, state) => const Text('Branch 2')),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/3', builder: (context, state) => const Text('Branch 3')),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/4', builder: (context, state) => const Text('Branch 4')),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
