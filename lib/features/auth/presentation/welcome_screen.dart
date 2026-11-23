import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/zameel_logo.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // 1. الشعار المعتمد للمنظومة (Brand Logo Mark)
              Center(
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tokens.brand.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.brand.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const ZameelLogo(
                    size: 64,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 2. اسم المنصة (Wordmark)
              Text(
                'زميل',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: tokens.textHigh,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 12),

              // 3. العنوان الرئيسي (Headline)
              Text(
                'نظّم مذاكرتك وتبادل الشرح مع زملائك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: tokens.textHigh,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 10),

              // 4. النص الفرعي (Subtitle)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'خطة مذاكرة أسبوعية، وجلسات شرح متبادلة بنظام عملات الوقت.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.textMedium,
                    height: 1.5,
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // 5. زر الإجراء الأساسي: ابدأ الآن -> /signup
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () => context.push('/signup'),
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.brand,
                    foregroundColor: tokens.onBrand,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadii.controlRadius,
                    ),
                  ),
                  child: const Text(
                    'ابدأ الآن',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 6. زر ثانوي: لدي حساب بالفعل -> /login
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => context.push('/login'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.brand,
                    side: BorderSide(color: tokens.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadii.controlRadius,
                    ),
                  ),
                  child: const Text(
                    'لدي حساب بالفعل',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
