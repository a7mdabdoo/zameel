// مطور 2
// فيجما: تسجيل الدخول - ذاكر وعلّم

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) {
        context.go('/today');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _errorMessage = 'البريد الإلكتروني غير مسجل، يرجى إنشاء حساب جديد.';
        } else if (e.code == 'wrong-password') {
          _errorMessage = 'كلمة المرور غير صحيحة.';
        } else {
          _errorMessage = e.message ?? 'فشل تسجيل الدخول. تحقق من البيانات.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'فشل تسجيل الدخول. تحقق من البيانات المدخلة.';
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
                const SizedBox(height: 12),
                Text(
                  'مرحباً بعودتك',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: tokens.textHigh,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'سجّل دخولك للوصول إلى خطتك الدراسية وجلسات بنك الوقت',
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.textMedium,
                  ),
                ),
                const SizedBox(height: 28),

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

                // Email field
                Text(
                  'البريد الجامعي أو الإلكتروني أو اسم المستخدم',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.textHigh,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: tokens.textHigh),
                  decoration: InputDecoration(
                    hintText: 'ahmed_dev أو student@gmail.com',
                    hintStyle: TextStyle(color: tokens.textLow),
                    hintTextDirection: TextDirection.ltr,
                    prefixIcon: Icon(Icons.alternate_email_rounded, color: tokens.textMedium),
                    filled: true,
                    fillColor: tokens.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: AppRadii.controlRadius,
                      borderSide: BorderSide(color: tokens.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadii.controlRadius,
                      borderSide: BorderSide(color: tokens.border),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال البريد الإلكتروني أو اسم المستخدم';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Password field
                Text(
                  'كلمة المرور',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.textHigh,
                  ),
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
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: tokens.textMedium,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: tokens.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: AppRadii.controlRadius,
                      borderSide: BorderSide(color: tokens.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadii.controlRadius,
                      borderSide: BorderSide(color: tokens.border),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      'نسيت كلمة المرور؟',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textMedium,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Login button -> Firebase Auth
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.brand,
                      foregroundColor: tokens.onBrand,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.controlRadius,
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: tokens.onBrand),
                          )
                        : Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: tokens.onBrand,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),

                // Sign up footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'ليس لديك حساب؟',
                      style: TextStyle(fontSize: 13, color: tokens.textMedium),
                    ),
                    TextButton(
                      onPressed: () => context.push('/signup'),
                      child: Text(
                        'أنشئ حساباً الآن',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: tokens.brand,
                        ),
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
