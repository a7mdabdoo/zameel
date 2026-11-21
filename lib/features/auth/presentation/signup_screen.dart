// مطور 2
// فيجما: إنشاء الحساب - ذاكر وعلّم

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_tokens.dart';
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
            username: _usernameController.text.trim().isNotEmpty ? _usernameController.text.trim() : _emailController.text.trim().split('@').first,
          );
      if (mounted) {
        context.go('/verify-email');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'email-already-in-use') {
          _errorMessage = 'هذا البريد مسجل مسبقاً، يرجى تسجيل الدخول.';
        } else if (e.code == 'weak-password') {
          _errorMessage = 'كلمة المرور ضعيفة جداً.';
        } else {
          _errorMessage = e.message ?? 'فشل إنشاء الحساب.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'فشل إنشاء الحساب. تأكد من البيانات والاتصال.';
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
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_forward_ios_rounded, color: tokens.textHigh),
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
                  'انضم إلى زميل',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: tokens.textHigh,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'أنشئ حسابك واحصل على ${AppConstants.welcomeCoins} عملات وقت ترحيبية لبدء التعلّم التشاركي',
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.textMedium,
                  ),
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: tokens.dangerContainer,
                      borderRadius: AppRadii.controlRadius,
                      border: Border.all(color: tokens.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 18, color: tokens.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(fontSize: 12.5, color: tokens.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Full Name field
                Text(
                  'الاسم بالكامل',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textHigh),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: tokens.textHigh),
                  decoration: InputDecoration(
                    hintText: 'أحمد محمود',
                    hintStyle: TextStyle(color: tokens.textLow),
                    prefixIcon: Icon(Icons.person_outline_rounded, color: tokens.textMedium),
                    filled: true,
                    fillColor: tokens.surfaceAlt,
                    border: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide(color: tokens.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide(color: tokens.border)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'يرجى إدخال اسمك';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Email field
                Text(
                  'البريد الجامعي أو الإلكتروني',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textHigh),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: tokens.textHigh),
                  decoration: InputDecoration(
                    hintText: 'student@fci.edu.eg أو yourname@gmail.com',
                    hintStyle: TextStyle(color: tokens.textLow),
                    hintTextDirection: TextDirection.ltr,
                    prefixIcon: Icon(Icons.email_outlined, color: tokens.textMedium),
                    filled: true,
                    fillColor: tokens.surfaceAlt,
                    border: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide(color: tokens.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide(color: tokens.border)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                    if (!AppConstants.isValidEmail(value.trim())) return 'صيغة البريد الإلكتروني غير صحيحة';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password field
                Text(
                  'كلمة المرور',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textHigh),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: tokens.textHigh),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: TextStyle(color: tokens.textLow),
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: tokens.textMedium),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: tokens.textMedium),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: tokens.surfaceAlt,
                    border: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide(color: tokens.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide(color: tokens.border)),
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textHigh),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscurePassword,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: tokens.textHigh),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: TextStyle(color: tokens.textLow),
                    prefixIcon: Icon(Icons.lock_reset_rounded, color: tokens.textMedium),
                    filled: true,
                    fillColor: tokens.surfaceAlt,
                    border: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide(color: tokens.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide(color: tokens.border)),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) return 'كلمات المرور غير متطابقة';
                    return null;
                  },
                ),

                const SizedBox(height: 28),

                // Submit button -> Next (Onboarding 1)
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handleSignUp,
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.brand,
                      foregroundColor: tokens.onBrand,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
                    ),
                    child: _isLoading
                        ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: tokens.onBrand))
                        : Text(
                            'إنشاء الحساب ومتابعة التهيئة',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.onBrand),
                          ),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('لديك حساب بالفعل؟', style: TextStyle(fontSize: 13, color: tokens.textMedium)),
                    TextButton(
                      onPressed: () => context.push('/login'),
                      child: Text(
                        'تسجيل الدخول',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.brand),
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
