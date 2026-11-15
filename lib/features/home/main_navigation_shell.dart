import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final hairlineColor = isDark ? AppColors.darkHairline : AppColors.hairline;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final containerColor = isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: hairlineColor, width: 1),
            ),
            color: surfaceColor,
          ),
          child: NavigationBar(
            height: 72,
            backgroundColor: surfaceColor,
            indicatorColor: containerColor,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onTap,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.today_outlined),
                selectedIcon: Icon(Icons.today, color: primaryColor),
                label: 'اليوم',
              ),
              NavigationDestination(
                icon: const Icon(Icons.calendar_view_week_outlined),
                selectedIcon: Icon(Icons.calendar_view_week, color: primaryColor),
                label: 'الخطة',
              ),
              NavigationDestination(
                icon: const Icon(Icons.handshake_outlined),
                selectedIcon: Icon(Icons.handshake, color: primaryColor),
                label: 'بنك الوقت',
              ),
              NavigationDestination(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet, color: primaryColor),
                label: 'المحفظة',
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person, color: primaryColor),
                label: 'حسابي',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
