import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_tokens.dart';

class MainNavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationShell({
    super.key,
    required this.navigationShell,
  });

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: tokens.border, width: 1),
            ),
            color: tokens.surface,
          ),
          child: NavigationBar(
            height: 72,
            backgroundColor: tokens.surface,
            indicatorColor: tokens.brandContainer,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onTap,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: tokens.brand),
                label: 'الرئيسية',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_view_week_outlined),
                selectedIcon: Icon(Icons.calendar_view_week, color: tokens.brand),
                label: 'الخطة',
              ),
              NavigationDestination(
                icon: Icon(Icons.forum_outlined),
                selectedIcon: Icon(Icons.forum_rounded, color: tokens.brand),
                label: 'المنتدى',
              ),
              NavigationDestination(
                icon: Icon(Icons.handshake_outlined),
                selectedIcon: Icon(Icons.handshake, color: tokens.brand),
                label: 'بنك الوقت',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person, color: tokens.brand),
                label: 'حسابي',
              ),
            ],
          ),
        ),
      ),
    );
  }
}