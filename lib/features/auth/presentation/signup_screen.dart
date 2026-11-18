// مطور 2
// فيجما: إنشاء الحساب - ذاكر وعلّم

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../data/auth_service.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            name: _nameController.text.trim(),
            username: _usernameController.text.trim(),
          );
      if (mounted) {
        context.go('/verify-email');
      }
    } on FirebaseException catch (e) {
      setState(() {
        if (e.code == 'email-already-in-use') {
          _errorMessage = 'هذا البريد مسجل بالفعل، يرجى تسجيل الدخول.';
        } else if (e.code == 'weak-password') {
          _errorMessage = 'كلمة المرور ضعيفة جداً. اختر كلمة مرور أقوى.';
        } else {
          _errorMessage = e.message ?? 'حدث خطأ أثناء إنشاء الحساب. تأكد من صحة البيانات.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimaryColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final inputFillColor = isDark ? AppColors.darkSurfaceAlt : AppColors.surface;
    final hairlineColor = isDark ? AppColors.darkHairline : AppColors.hairline;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_forward_ios_rounded, color: textPrimaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'انضم إلى زَميل 🎓',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'أنشئ حسابك واحصل على ${AppConstants.welcomeCoins} عملات وقت ترحيبية لبدء التعلّم التشاركي',
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Full Name
                Text(
                  'الاسم بالكامل',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimaryColor),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: textPrimaryColor),
                  decoration: InputDecoration(
                    hintText: 'أحمد محمود',
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textTertiary),
                    filled: true,
                    fillColor: inputFillColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairlineColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairlineColor)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'يرجى إدخال اسمك';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Username (Codeforces / LinkedIn style)
                Text(
                  'اسم المستخدم (Username)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimaryColor),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameController,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: textPrimaryColor),
                  decoration: InputDecoration(
                    hintText: 'ahmed_dev',
                    hintTextDirection: TextDirection.ltr,
                    prefixIcon: const Icon(Icons.alternate_email_rounded, color: AppColors.textTertiary),
                    filled: true,
                    fillColor: inputFillColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairlineColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairlineColor)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'يرجى إدخال اسم المستخدم';
                    final clean = value.trim();
                    if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(clean)) {
                      return 'الاسم يجب أن يكون بالإنجليزية (3-20 حرفاً أو أرقاماً أو _)';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Email
                Text(
                  'البريد الإلكتروني (Gmail أو أي بريد شخصي)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimaryColor),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: textPrimaryColor),
                  decoration: InputDecoration(
                    hintText: 'yourname@gmail.com',
                    hintTextDirection: TextDirection.ltr,
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textTertiary),
                    filled: true,
                    fillColor: inputFillColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairlineColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairlineColor)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال البريد الإلكتروني';
                    }
                    if (!AppConstants.isValidEmail(value)) {
                      return 'يرجى إدخال بريد إلكتروني صحيح (مثل yourname@gmail.com)';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password
                Text(
                  'كلمة المرور',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimaryColor),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: textPrimaryColor),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textTertiary),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textTertiary),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: inputFillColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairlineColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairlineColor)),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) return 'يجب أن لا تقل عن 6 أحرف';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Confirm Password
                Text(
                  'تأكيد كلمة المرور',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimaryColor),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscurePassword,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: textPrimaryColor),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.textTertiary),
                    filled: true,
                    fillColor: inputFillColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairlineColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairlineColor)),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) return 'كلمات المرور غير متطابقة';
                    return null;
                  },
                ),

                const SizedBox(height: 28),

                // Submit button -> Next (Onboarding 1)
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                      foregroundColor: isDark ? AppColors.darkOnPrimary : AppColors.onPrimary,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            'إنشاء الحساب ومتابعة التهيئة',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkOnPrimary : AppColors.onPrimary),
                          ),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('لديك حساب بالفعل؟', style: TextStyle(fontSize: 13, color: textSecondaryColor)),
                    TextButton(
                      onPressed: () => context.push('/login'),
                      child: Text(
                        'تسجيل الدخول',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
