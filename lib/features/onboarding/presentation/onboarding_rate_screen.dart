// مطور 2
// فيجما: التهيئة: قيّم نفسك - ذاكر وعلّم

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_service.dart';

class OnboardingRateScreen extends ConsumerStatefulWidget {
  final List<CourseSeed>? courses;

  const OnboardingRateScreen({super.key, this.courses});

  @override
  ConsumerState<OnboardingRateScreen> createState() => _OnboardingRateScreenState();
}

class _OnboardingRateScreenState extends ConsumerState<OnboardingRateScreen> {
  late final List<CourseSeed> _courses;
  late final Map<String, int> _ratings;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _courses = widget.courses ?? AppConstants.seedCourses;
    _ratings = {
      for (final c in _courses)
        c.id: _defaultRatingFor(c.id),
    };
  }

  int _defaultRatingFor(String id) {
    switch (id) {
      case 'cs201': return 3; // OOP متمكن
      case 'cs202': return 2; // Data Structures متوسط
      case 'is201': return 2; // Databases متوسط
      case 'math201': return 1; // Linear Algebra أحتاج مساعدة
      case 'math202': return 1; // Calculus أحتاج مساعدة
      case 'cs203': return 3; // Computer Org متمكن
      default: return 2;      // افتراضي للمواد المضافة: متوسط
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(authServiceProvider).updateUserProfile(
        selectedCourses: _courses.map((c) => c.id).toList(),
        coursesData: _courses.map((c) => c.toMap()).toList(),
        courseRatings: _ratings,
        onboardingCompleted: true,
      );

      if (mounted) {
        context.go('/today');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر حفظ البيانات: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final surfaceAltColor = isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt;
    final hairlineColor = isDark ? AppColors.darkHairline : AppColors.hairline;
    final textPrimaryColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_forward_ios_rounded, color: textPrimaryColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'الخطوة 3 من 3',
          style: TextStyle(fontSize: 14, color: textSecondaryColor, fontWeight: FontWeight.w600),
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
                      Expanded(child: Container(height: 4, decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(width: 6),
                      Expanded(child: Container(height: 4, decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(width: 6),
                      Expanded(child: Container(height: 4, decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(2)))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'قيّم مستواك في المواد 🎯',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimaryColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'لتوجيه خوارزمية التوافق الذكي لبنك الوقت بين المتعلمين والشارحين',
                    style: TextStyle(fontSize: 13, color: textSecondaryColor),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // Courses Rating List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                itemCount: _courses.length,
                itemBuilder: (context, index) {
                  final course = _courses[index];
                  final currentRate = _ratings[course.id] ?? 2;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: hairlineColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
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
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimaryColor),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: course.creditHours >= 3
                                    ? primaryColor.withValues(alpha: isDark ? 0.3 : 0.2)
                                    : surfaceAltColor,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: course.creditHours >= 3
                                      ? primaryColor.withValues(alpha: 0.4)
                                      : hairlineColor,
                                ),
                              ),
                              child: Text(
                                '${course.creditHours} س',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: course.creditHours >= 3 ? primaryColor : textSecondaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              course.code,
                              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildRateOption(course.id, 1, 'أحتاج مساعدة', currentRate == 1, Colors.orange.shade700),
                            const SizedBox(width: 8),
                            _buildRateOption(course.id, 2, 'متوسط', currentRate == 2, primaryColor),
                            const SizedBox(width: 8),
                            _buildRateOption(course.id, 3, 'مستعد للشرح', currentRate == 3, isDark ? AppColors.darkPrimary : AppColors.deepSage),
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
                  icon: Icon(Icons.check_circle_outline_rounded, color: isDark ? AppColors.darkOnPrimary : AppColors.onPrimary, size: 20),
                  label: _isSaving
                      ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: isDark ? AppColors.darkOnPrimary : AppColors.onPrimary, strokeWidth: 2))
                      : Text(
                          'ابدأ رحلتك في زَميل',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkOnPrimary : AppColors.onPrimary),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
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
