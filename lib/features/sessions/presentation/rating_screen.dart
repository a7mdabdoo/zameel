// مطور 1
// فيجما: التقييم وتحويل الرصيد - ذاكر وعلّم (المعاملة الذرية الحقيقية مع الضمان)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/app_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_service.dart';
import '../../timebank/data/timebank_repository.dart';

class RatingScreen extends ConsumerStatefulWidget {
  final TimeBankSessionModel? session;
  const RatingScreen({super.key, this.session});

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  int _rating = 5;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRatingAndTransfer() async {
    final session = widget.session;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بيانات الجلسة غير متوفرة')),
      );
      return;
    }

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final comment = _commentController.text.trim().isEmpty
          ? 'شرح ممتاز ومفيد جداً، شكراً للزميل على وقته ومجهوده!'
          : _commentController.text.trim();

      await ref.read(timeBankRepositoryProvider).completeSessionAndReleaseEscrow(
            sessionId: session.id,
            learnerId: user.uid,
            rating: _rating,
            reviewComment: comment,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إتمام الجلسة وتحويل عملة الوقت إلى ${session.teacherName} بنجاح! شكراً لك 🎉')),
        );
        context.go('/my-sessions');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إتمام الجلسة وإطلاق الضمان: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final teacherName = session?.teacherName ?? 'الزميل الشارح';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_forward_ios_rounded, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'تقييم الجلسة وإطلاق العملة ⭐',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
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
                    color: AppColors.primaryContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    size: 38,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'كيف كانت جلسة الشرح مع $teacherName؟',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 6),
              const Text(
                'تقييمك يساعد زملاءك في التعرف على تميز الشارح ويزيد من موثوقية بنك الوقت.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 28),

              // Star Rating Selector
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        final isFilled = starValue <= _rating;
                        return IconButton(
                          iconSize: 36,
                          icon: Icon(
                            isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                            color: isFilled ? AppColors.pointsAmber : AppColors.textTertiary,
                          ),
                          onPressed: () => setState(() => _rating = starValue),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _rating == 5
                          ? 'ممتاز جداً 🌟'
                          : _rating == 4
                              ? 'جيد جداً 👍'
                              : _rating == 3
                                  ? 'متوسط 👌'
                                  : _rating == 2
                                      ? 'مقبول'
                                      : 'بحاجة لتحسين',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Comment field
              Text(
                'ملاحظاتك للزميل (اختياري)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'اكتب كلمة شكر أو ملاحظات ساعدتك أثناء الشرح...',
                  filled: true,
                  fillColor: Theme.of(context).cardTheme.color,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.hairline)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.hairline)),
                ),
              ),

              const SizedBox(height: 24),

              // Transfer Notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_rounded, color: AppColors.primary, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'عند الضغط على الزر، سيتم فك حجز الضمان وتحويل 1 عملة وقت إلى محفظة الشارح فوراً.',
                        style: TextStyle(fontSize: 12, color: AppColors.primary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Submit Button
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitRatingAndTransfer,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white),
                  label: Text(
                    _isSubmitting ? 'جاري تحرير الضمان والتقييم...' : 'إرسال التقييم وإطلاق عملة الوقت',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
