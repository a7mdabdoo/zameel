import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
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
  Object? initError;
  try {
    await Firebase.initializeApp();
  } catch (e) {
    initError = e;
    debugPrint('Firebase initialization failed: $e');
  }

  if (initError != null) {
    runApp(FirebaseInitErrorApp(error: initError));
    return;
  }

  runApp(
    const ProviderScope(
      child: ZameelApp(),
    ),
  );
}

/// شاشة خطأ كاملة تظهر باللغة العربية عند فشل تهيئة Firebase مع زر إعادة المحاولة
class FirebaseInitErrorApp extends StatefulWidget {
  final Object error;
  const FirebaseInitErrorApp({super.key, required this.error});

  @override
  State<FirebaseInitErrorApp> createState() => _FirebaseInitErrorAppState();
}

class _FirebaseInitErrorAppState extends State<FirebaseInitErrorApp> {
  bool _isRetrying = false;
  String? _lastError;

  Future<void> _retry() async {
    setState(() {
      _isRetrying = true;
      _lastError = null;
    });

    try {
      await Firebase.initializeApp();
      runApp(
        const ProviderScope(
          child: ZameelApp(),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRetrying = false;
          _lastError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayError = _lastError ?? widget.error.toString();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_off_rounded,
                        size: 46,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'تعذر الاتصال بخدمات زَميل',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'حدث خطأ غير متوقع أثناء تهيئة خدمات Firebase الأساسية.\nيرجى التأكد من اتصالك بالإنترنت ثم إعادة المحاولة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Text(
                        displayError,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isRetrying ? null : _retry,
                        icon: _isRetrying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, color: Colors.white),
                        label: Text(
                          _isRetrying ? 'جارٍ إعادة المحاولة...' : 'إعادة المحاولة',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
