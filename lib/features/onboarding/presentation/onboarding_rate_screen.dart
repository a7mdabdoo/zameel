// مطور 2
// فيجما: التهيئة: قيّم نفسك - ذاكر وعلّم

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_service.dart';

class OnboardingRateScreen extends ConsumerStatefulWidget {
  const OnboardingRateScreen({super.key});

  @override
  ConsumerState<OnboardingRateScreen> createState() => _OnboardingRateScreenState();
}

class _OnboardingRateScreenState extends ConsumerState<OnboardingRateScreen> {
  // خريطة التقييم: 1 = أحتاج مساعدة (مبتدئ), 2 = متوسط, 3 = مستعد للشرح (متمكن)
  final Map<String, int> _ratings = {
    'cs201': 3, // OOP متمكن
    'cs202': 2, // Data Structures متوسط
    'is201': 2, // Databases متوسط
    'math201': 1, // Linear Algebra أحتاج مساعدة
    'math202': 1, // Calculus أحتاج مساعدة
    'cs203': 3, // Computer Org متمكن
  };

  bool _isSaving = false;

  Future<void> _finishOnboarding() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(authServiceProvider).updateUserProfile(
        courseRatings: _ratings,
      );
    } catch (_) {}

    if (mounted) {
      context.go('/today');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'الخطوة 3 من 3',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress indicator: 3 of 3 full
                  Row(
                    children: [
                      Expanded(child: Container(height: 4, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(width: 6),
                      Expanded(child: Container(height: 4, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(width: 6),
                      Expanded(child: Container(height: 4, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'قيّم مستواك في المواد 🎯',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'لتوجيه خوارزمية التوافق الذكي لبنك الوقت بين المتعلمين والشارحين',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // Courses Rating List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                itemCount: AppConstants.seedCourses.length,
                itemBuilder: (context, index) {
                  final course = AppConstants.seedCourses[index];
                  final currentRate = _ratings[course.id] ?? 2;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.hairline),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: course.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                course.name,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ),
                            Text(
                              course.code,
                              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildRateOption(course.id, 1, 'أحتاج مساعدة', currentRate == 1, Colors.orange.shade700),
                            const SizedBox(width: 8),
                            _buildRateOption(course.id, 2, 'متوسط', currentRate == 2, AppColors.primary),
                            const SizedBox(width: 8),
                            _buildRateOption(course.id, 3, 'مستعد للشرح', currentRate == 3, AppColors.deepSage),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Start Journey Button -> /today
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _finishOnboarding,
                  icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                  label: _isSaving
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text(
                          'ابدأ رحلتك في زَميل',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateOption(String courseId, int score, String label, bool isSelected, Color activeColor) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _ratings[courseId] = score;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.12) : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? activeColor : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
