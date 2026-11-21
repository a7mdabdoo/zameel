import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_tokens.dart';
import 'core/routing/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/state/app_state.dart';
import 'core/l10n/app_localizations.dart';
import 'core/services/global_notification_listener.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isDarkSaved = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    isDarkSaved = prefs.getBool('zameel_is_dark_theme') ?? false;
  } catch (e) {
    debugPrint('Prefs init error: $e');
  }

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
    ProviderScope(
      overrides: [
        if (isDarkSaved)
          initialThemeModeProvider.overrideWithValue(ThemeMode.dark),
      ],
      child: const ZameelApp(),
    ),
  );
}
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
      bool isDarkSaved = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        isDarkSaved = prefs.getBool('zameel_is_dark_theme') ?? false;
      } catch (_) {}

      runApp(
        ProviderScope(
          overrides: [
            if (isDarkSaved)
              initialThemeModeProvider.overrideWithValue(ThemeMode.dark),
          ],
          child: const ZameelApp(),
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
    const tokens = AppTokens.light;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: tokens.bg,
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
                        color: tokens.dangerContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cloud_off_rounded,
                        size: 46,
                        color: tokens.danger,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'تعذر الاتصال بخدمات زميل',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: tokens.textHigh,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'حدث خطأ غير متوقع أثناء تهيئة خدمات Firebase الأساسية.\nيرجى التأكد من اتصالك بالإنترنت ثم إعادة المحاولة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: tokens.textMedium,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.surfaceAlt,
                        borderRadius: AppRadii.controlRadius,
                        border: Border.all(color: tokens.border),
                      ),
                      child: Text(
                        displayError,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: tokens.textMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _isRetrying ? null : _retry,
                        icon: _isRetrying
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: tokens.onBrand,
                                ),
                              )
                            : Icon(Icons.refresh_rounded),
                        label: Text(
                          _isRetrying ? 'جارٍ إعادة المحاولة...' : 'إعادة المحاولة',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.brand,
                          foregroundColor: tokens.onBrand,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadii.controlRadius,
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
      builder: (context, child) {
        return GlobalNotificationListener(
          child: child ?? const SizedBox.shrink(),
        );
      },
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}