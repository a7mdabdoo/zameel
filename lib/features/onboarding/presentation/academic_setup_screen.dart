import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../auth/data/auth_service.dart';

class AcademicSetupScreen extends ConsumerStatefulWidget {
  final bool isEditMode;

  const AcademicSetupScreen({
    super.key,
    this.isEditMode = false,
  });

  @override
  ConsumerState<AcademicSetupScreen> createState() => _AcademicSetupScreenState();
}

class _AcademicSetupScreenState extends ConsumerState<AcademicSetupScreen> {
  int _selectedYear = 1; // 1: الفرقة الأولى, 2: الفرقة الثانية, 3: الثالثة, 4: الرابعة
  int _selectedSemester = 1; // 1: الترم الأول, 2: الترم الثاني
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // قراءة البيانات الحالية إذا كان المستخدم في وضع التعديل
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userDoc = ref.read(userProfileStreamProvider).value?.data();
      if (userDoc != null) {
        final existingYear = userDoc['academicYear'];
        final existingSem = userDoc['semester'];
        if (existingYear is int && existingYear >= 1 && existingYear <= 4) {
          setState(() => _selectedYear = existingYear);
        } else if (existingYear is String) {
          final parsed = int.tryParse(existingYear);
          if (parsed != null && parsed >= 1 && parsed <= 4) {
            setState(() => _selectedYear = parsed);
          }
        }
        if (existingSem is int && (existingSem == 1 || existingSem == 2)) {
          setState(() => _selectedSemester = existingSem);
        } else if (existingSem is String) {
          final parsed = int.tryParse(existingSem);
          if (parsed != null && (parsed == 1 || parsed == 2)) {
            setState(() => _selectedSemester = parsed);
          }
        }
      }
    });
  }

  Future<void> _handleConfirm() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final courses = CurriculumConstants.getCoursesFor(_selectedYear, _selectedSemester);

      // حفظ بيانات الفرقة والفصل وإسناد المواد (Idempotent)
      await ref.read(authServiceProvider).saveAcademicSetup(
            academicYear: _selectedYear,
            semester: _selectedSemester,
            courses: courses,
          );

      // تأكيد الإكمال محلياً فوراً وإعادة توليد خطة المذاكرة للمواد الجديدة
      ref.read(localOnboardingCompletedProvider.notifier).markCompleted();
      ref.read(plannerProvider.notifier).updateCoursesAndRegeneratePlan(
            courses,
            {for (final c in courses) c.id: 2},
          );
      ref.invalidate(userProfileStreamProvider);

      if (mounted) {
        // الانتقال للوحة التحكم الرئيسية فوراً
        context.go('/today');
      }
    } catch (e, stackTrace) {
      debugPrint('AcademicSetupScreen error saving courses: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر حفظ المواد الدراسية، يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.';
        });
      }
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
    final previewCourses = CurriculumConstants.getCoursesFor(_selectedYear, _selectedSemester);
    final yearName = CurriculumConstants.academicYearLabels[_selectedYear] ?? 'الفرقة الأولى';
    final semesterName = CurriculumConstants.semesterLabels[_selectedSemester] ?? 'الترم الأول';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: widget.isEditMode
            ? IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textPrimary),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(
          widget.isEditMode ? 'تعديل البيانات الأكاديمية ✏️' : 'التهيئة الأكاديمية 🎓',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Intro Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.hairline),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'اختر فرقتك وفصلك الدراسي',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'سنقوم بتهيئة مقرراتك الرسمية وجدولك الدراسي بناءً على الخطة المعتمدة فوراً.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Error Banner if any
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12, color: AppColors.error),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 1. الفرقة الدراسية (Academic Year)
                    const Text(
                      'الفرقة الدراسية',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildYearSelector(),

                    const SizedBox(height: 22),

                    // 2. الفصل الدراسي (Semester)
                    const Text(
                      'الفصل الدراسي',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildSemesterSelector(),

                    const SizedBox(height: 24),

                    // 3. Live Preview Card (قائمة المقررات المعتمدة)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'المقررات المقررة (معاينة حية)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$yearName • $semesterName (${previewCourses.length} مواد)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildCoursesPreviewList(previewCourses),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Bottom Confirmation Button Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: AppColors.hairline)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'تأكيد وإضافة المواد',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// أزرار اختيار الفرقة الدراسية (1 إلى 4)
  Widget _buildYearSelector() {
    final years = [
      {'id': 1, 'label': 'الفرقة الأولى', 'sub': 'السنة 1'},
      {'id': 2, 'label': 'الفرقة الثانية', 'sub': 'السنة 2'},
      {'id': 3, 'label': 'الفرقة الثالثة', 'sub': 'السنة 3'},
      {'id': 4, 'label': 'الفرقة الرابعة', 'sub': 'السنة 4 (التخرج)'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: years.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final item = years[index];
        final id = item['id'] as int;
        final label = item['label'] as String;
        final sub = item['sub'] as String;
        final isSelected = _selectedYear == id;

        return InkWell(
          onTap: () {
            if (_selectedYear != id) {
              setState(() => _selectedYear = id);
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.35) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.hairline,
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isSelected ? AppColors.primary : AppColors.surfaceAlt,
                  child: Text(
                    '$id',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        sub,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  /// أزرار اختيار الفصل الدراسي (الترم الأول أو الثاني)
  Widget _buildSemesterSelector() {
    final semesters = [
      {'id': 1, 'label': 'الترم الأول', 'icon': Icons.looks_one_rounded},
      {'id': 2, 'label': 'الترم الثاني', 'icon': Icons.looks_two_rounded},
    ];

    return Row(
      children: semesters.map((item) {
        final id = item['id'] as int;
        final label = item['label'] as String;
        final icon = item['icon'] as IconData;
        final isSelected = _selectedSemester == id;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: id == 1 ? 6.0 : 0.0,
              right: id == 2 ? 6.0 : 0.0,
            ),
            child: InkWell(
              onTap: () {
                if (_selectedSemester != id) {
                  setState(() => _selectedSemester = id);
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.35) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.hairline,
                    width: isSelected ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 16),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// قائمة المعاينة الحية للمواد
  Widget _buildCoursesPreviewList(List<CourseSeed> courses) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: courses.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.hairline),
        itemBuilder: (context, index) {
          final course = courses[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // رقم المادة واللون
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: course.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: course.color.withValues(alpha: 0.4)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: course.color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // اسم المادة
                Expanded(
                  child: Text(
                    course.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // كود المادة
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    course.code,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // الساعات المعتمدة
                Text(
                  course.creditHours == 2 ? 'ساعتان' : '${course.creditHours} س',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
