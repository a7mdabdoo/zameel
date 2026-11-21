import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/auth_service.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  Timer? _checkTimer;
  bool _isChecking = false;
  bool _isResending = false;
  String? _message;
  bool _isSuccessMessage = false;

  @override
  void initState() {
    super.initState();
    // فحص دوري تلقائي كل 3 ثوانٍ للكشف المباشر عند تأكيد البريد من الهاتف
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final isVerified = await ref.read(authServiceProvider).reloadUserAndCheckVerified();
      if (isVerified && mounted) {
        _checkTimer?.cancel();
        context.go('/academic-setup');
      }
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    setState(() {
      _isChecking = true;
      _message = null;
    });

    try {
      final isVerified = await ref.read(authServiceProvider).reloadUserAndCheckVerified();
      if (!mounted) return;

      if (isVerified) {
        _checkTimer?.cancel();
        context.go('/academic-setup');
      } else {
        setState(() {
          _isSuccessMessage = false;
          _message = 'لم يتم تأكيد البريد بعد. يرجى فتح الرسالة في بريدك الإلكتروني والضغط على الرابط ثم إعادة المحاولة.';
        });
      }
    } catch (e) {
      setState(() {
        _isSuccessMessage = false;
        _message = 'حدث خطأ أثناء فحص التأكيد. حاول مرة أخرى.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _resendEmail() async {
    setState(() {
      _isResending = true;
      _message = null;
    });

    try {
      await ref.read(authServiceProvider).sendEmailVerification();
      setState(() {
        _isSuccessMessage = true;
        _message = 'تمت إعادة إرسال رابط التأكيد إلى بريدك بنجاح.';
      });
    } catch (e) {
      setState(() {
        _isSuccessMessage = false;
        _message = 'تعذر إرسال الرابط الآن. يرجى الانتظار دقيقة قبل المحاولة مجدداً.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final user = ref.read(authServiceProvider).currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: tokens.brandContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_unread_outlined,
                    size: 48,
                    color: tokens.brand,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'تأكيد البريد الإلكتروني',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: tokens.textHigh,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'أرسلنا رابط تأكيد إلى:\n$email\nيرجى تأكيد بريدك لتفعيل الحساب وحماية رصيدك في بنك الوقت.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: tokens.textMedium,
                ),
              ),
              const SizedBox(height: 24),

              if (_message != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSuccessMessage ? tokens.successContainer : tokens.dangerContainer,
                    borderRadius: AppRadii.controlRadius,
                    border: Border.all(
                      color: _isSuccessMessage
                          ? tokens.success.withValues(alpha: 0.3)
                          : tokens.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: _isSuccessMessage ? tokens.success : tokens.danger,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Check button
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _isChecking ? null : _checkVerification,
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.brand,
                    foregroundColor: tokens.onBrand,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadii.controlRadius,
                    ),
                  ),
                  child: _isChecking
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: tokens.onBrand, strokeWidth: 2),
                        )
                      : Text(
                          'لقد قمت بالتأكيد (دخول)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tokens.onBrand),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Resend link button
              OutlinedButton(
                onPressed: _isResending ? null : _resendEmail,
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.brand,
                  side: BorderSide(color: tokens.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadii.controlRadius,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isResending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'إعادة إرسال رابط التأكيد',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.brand),
                      ),
              ),

              const Spacer(),

              // Sign out option
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) {
                      context.go('/welcome');
                    }
                  },
                  icon: Icon(Icons.logout_rounded, size: 18, color: tokens.textLow),
                  label: Text(
                    'تسجيل الخروج واستخدام حساب آخر',
                    style: TextStyle(fontSize: 13, color: tokens.textLow),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
