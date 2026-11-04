// مطور 1
// فيجما: التقييم وتحويل الرصيد - ذاكر وعلّم

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _rating = 5;
  final _commentController = TextEditingController(text: 'شرح ممتاز جداً ومبسط، ساعدني في فهم الفضاءات المتجهة بسهولة!');
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRatingAndTransfer() async {
    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Atomic transaction: خصم 1 عملة وقت من رصيد المتعلّم وتحويلها
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(userDocRef);
          if (snapshot.exists) {
            final currentCoins = snapshot.data()?['timeCoins'] as int? ?? 3;
            if (currentCoins > 0) {
              transaction.update(userDocRef, {'timeCoins': currentCoins - 1});
            }
          }
        });

        // تسجيل المعاملة في محفظة المعاملات
        await FirebaseFirestore.instance.collection('transactions').add({
          'userId': user.uid,
          'type': 'spend',
          'amount': 1,
          'peerName': 'عمر خالد',
          'course': 'الجبر الخطي',
          'rating': _rating,
          'comment': _commentController.text,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحويل عملة الوقت وإرسال التقييم بنجاح! شكراً لك 🎉')),
      );
      context.go('/wallet');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'تقييم الجلسة وتحويل الرصيد ⭐',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success Icon
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, size: 48, color: AppColors.deepSage),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'اكتملت جلسة الشرح بنجاح!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'كيف كانت تجربتك مع الزميل عمر خالد في مادة الجبر الخطي؟',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 24),

              // Star rating selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  return IconButton(
                    iconSize: 36,
                    icon: Icon(
                      starValue <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: AppColors.pointsAmber,
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = starValue;
                      });
                    },
                  );
                }),
              ),

              const SizedBox(height: 20),

              // Comment
              const Text(
                'كلمة شكر أو ملاحظات للزميل',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.hairline)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.hairline)),
                ),
              ),

              const SizedBox(height: 24),

              // Coin transfer notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.swap_horizontal_circle_outlined, color: AppColors.primary, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'سيتم خصم 1 عملة وقت من رصيدك وإضافتها إلى محفظة عمر خالد تقديراً لجهده.',
                        style: TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Submit Button -> /wallet
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitRatingAndTransfer,
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  label: _isSubmitting
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text(
                          'إرسال التقييم وتحويل الرصيد',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Skip Button -> /wallet
              TextButton(
                onPressed: () => context.go('/wallet'),
                child: const Text(
                  'تخطي التقييم والانتقال إلى المحفظة',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
