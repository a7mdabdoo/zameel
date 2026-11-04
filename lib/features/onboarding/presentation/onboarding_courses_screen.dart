// مطور 2
// فيجما: التهيئة: موادك - ذاكر وعلّم

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

class OnboardingCoursesScreen extends StatefulWidget {
  const OnboardingCoursesScreen({super.key});

  @override
  State<OnboardingCoursesScreen> createState() => _OnboardingCoursesScreenState();
}

class _OnboardingCoursesScreenState extends State<OnboardingCoursesScreen> {
  // الافتراضي تحديد كل المواد المسجلة في الفصل
  final Set<String> _selectedCourseIds = {
    'cs201',
    'cs202',
    'is201',
    'math201',
    'math202',
    'cs203',
  };

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
          'الخطوة 2 من 3',
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
                  // Progress indicator
                  Row(
                    children: [
                      Expanded(child: Container(height: 4, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(width: 6),
                      Expanded(child: Container(height: 4, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(width: 6),
                      Expanded(child: Container(height: 4, decoration: BoxDecoration(color: AppColors.hairline, borderRadius: BorderRadius.circular(2)))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'اختر مواد الفصل الدراسي 📚',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'تم تحديد 6 مواد مقترحة لطلاب الفرقة الثانية (${_selectedCourseIds.length} محددة)',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // Courses list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                itemCount: AppConstants.seedCourses.length,
                itemBuilder: (context, index) {
                  final course = AppConstants.seedCourses[index];
                  final isSelected = _selectedCourseIds.contains(course.id);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? course.color : AppColors.hairline,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: course.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            course.code.substring(0, 2),
                            style: TextStyle(
                              color: course.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        course.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        course.code,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: Checkbox(
                        value: isSelected,
                        activeColor: course.color,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (bool? checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedCourseIds.add(course.id);
                            } else {
                              _selectedCourseIds.remove(course.id);
                            }
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedCourseIds.remove(course.id);
                          } else {
                            _selectedCourseIds.add(course.id);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),

            // Bottom CTA
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _selectedCourseIds.isEmpty
                      ? null
                      : () => context.push('/onboarding-rate'),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'التالي: تقييم مستواك',
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
}
