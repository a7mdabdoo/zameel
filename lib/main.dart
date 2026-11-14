import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/state/app_state.dart';
import 'core/l10n/app_localizations.dart';

// ==========================================
// نقطة البداية لتطبيق زَميل (Zameel App)
// تهيئة خدمات Firebase وتشغيل واجهة التطبيق مع إدارة الحالة عبر Riverpod
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();

  } catch (e) {
    debugPrint('Firebase init warning: $e');
  }

  runApp(
    const ProviderScope(
      child: ZameelApp(),
    ),
  );
}

/// الويدجت الرئيسي للتطبيق مع دعم الثيم الفاتح/الداكن والتوجيه ودعم اللغة العربية
class ZameelApp extends ConsumerWidget {
  const ZameelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    );
  }
}
