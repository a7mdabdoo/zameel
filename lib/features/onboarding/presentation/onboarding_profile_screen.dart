// مطور 2
// فيجما: التهيئة: بياناتك - ذاكر وعلّم

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/data/auth_service.dart';

class OnboardingProfileScreen extends ConsumerStatefulWidget {
  const OnboardingProfileScreen({super.key});

  @override
  ConsumerState<OnboardingProfileScreen> createState() => _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends ConsumerState<OnboardingProfileScreen> {
  final String _selectedFaculty = 'كلية الحاسبات والذكاء الاصطناعي';
  final String _selectedYear = 'الفرقة الثانية';
  String _selectedDepartment = 'عام (General)';

  final List<String> _departments = [
    'عام (General)',
    'علوم الحاسب (CS)',
    'نظم المعلومات (IS)',
    'الذكاء الاصطناعي (AI)',
    'تكنولوجيا المعلومات (IT)',
  ];

  void _skipOnboarding() {
    // حفظ التفضيلات وإتمام التهيئة في الخلفية دون أي تعطيل لدخول المستخدم
    ref.read(authServiceProvider).updateUserProfile(
      faculty: _selectedFaculty,
      year: _selectedYear,
      department: _selectedDepartment,
      onboardingCompleted: true,
    );
    context.go('/today');
  }

  void _proceedToCourses() {
    // حفظ بيانات الملف الشخصي والانتقال لاختيار المواد
    ref.read(authServiceProvider).updateUserProfile(
      faculty: _selectedFaculty,
      year: _selectedYear,
      department: _selectedDepartment,
    );
    context.push('/onboarding-courses');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'الخطوة 1 من 3',
          style: TextStyle(fontSize: 14, color: tokens.textMedium, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _skipOnboarding,
            child: Text(
              'تخطي',
              style: TextStyle(
                color: tokens.brand,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress indicator
              Row(
                children: [
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(color: tokens.brand, borderRadius: AppRadii.controlRadius))),
                  const SizedBox(width: 6),
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(color: tokens.border, borderRadius: AppRadii.controlRadius))),
                  const SizedBox(width: 6),
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(color: tokens.border, borderRadius: AppRadii.controlRadius))),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                'بياناتك الأكاديمية',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: tokens.textHigh,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'لتخصيص المواد ومطابقة مواعيدك مع زملاء دفعتك',
                style: TextStyle(
                  fontSize: 14,
                  color: tokens.textMedium,
                ),
              ),
              const SizedBox(height: 28),

              // Faculty
              Text(
                'الكلية',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textHigh),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: AppRadii.controlRadius,
                  border: Border.all(color: tokens.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.school_outlined, color: tokens.brand, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedFaculty,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textHigh),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Year
              Text(
                'السنة الدراسية',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textHigh),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: AppRadii.controlRadius,
                  border: Border.all(color: tokens.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.date_range_outlined, color: tokens.brand, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedYear,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textHigh),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Department Dropdown
              Text(
                'القسم الأكاديمي',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textHigh),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: AppRadii.controlRadius,
                  border: Border.all(color: tokens.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDepartment,
                    isExpanded: true,
                    dropdownColor: tokens.surface,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: tokens.textMedium),
                    items: _departments.map((dept) {
                      return DropdownMenuItem<String>(
                        value: dept,
                        child: Text(dept, style: TextStyle(fontSize: 14, color: tokens.textHigh)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDepartment = val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Next CTA
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _proceedToCourses,
                  icon: Icon(Icons.arrow_back_rounded, color: tokens.onBrand, size: 20),
                  label: Text(
                    'التالي: اختيار المواد',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.onBrand),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brand,
                    foregroundColor: tokens.onBrand,
                    shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
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
