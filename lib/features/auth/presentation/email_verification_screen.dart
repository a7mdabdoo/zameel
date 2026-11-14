import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
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
        context.go('/onboarding-profile');
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
        context.go('/onboarding-profile');
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
    final user = ref.read(authServiceProvider).currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
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
                    color: AppColors.primaryContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'تأكيد البريد الإلكتروني',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'أرسلنا رابط تأكيد إلى:\n$email\nيرجى تأكيد بريدك لتفعيل الحساب وحماية رصيدك في بنك الوقت.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              if (_message != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSuccessMessage
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isSuccessMessage
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: _isSuccessMessage ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Check button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _checkVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'لقد قمت بالتأكيد (دخول)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Resend link button
              OutlinedButton(
                onPressed: _isResending ? null : _resendEmail,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.hairline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isResending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'إعادة إرسال رابط التأكيد',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                  icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.textTertiary),
                  label: const Text(
                    'تسجيل الخروج واستخدام حساب آخر',
                    style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
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
