import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_tokens.dart';
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
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: widget.isEditMode
            ? IconButton(
                icon: Icon(Icons.arrow_forward_ios_rounded, color: tokens.textHigh),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(
          widget.isEditMode ? 'تعديل البيانات الأكاديمية' : 'التهيئة الأكاديمية',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: tokens.textHigh,
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
                        color: tokens.surface,
                        borderRadius: AppRadii.cardRadius,
                        border: Border.all(color: tokens.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: tokens.brand.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.school_rounded, color: tokens.brand, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'اختر فرقتك وفصلك الدراسي',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.textHigh,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'سنقوم بتهيئة مقرراتك الرسمية وجدولك الدراسي بناءً على الخطة المعتمدة فوراً.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tokens.textMedium,
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
                          color: tokens.dangerContainer,
                          borderRadius: AppRadii.controlRadius,
                          border: Border.all(color: tokens.danger.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(fontSize: 12, color: tokens.danger),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 1. الفرقة الدراسية (Academic Year)
                    Text(
                      'الفرقة الدراسية',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: tokens.textHigh,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildYearSelector(),

                    const SizedBox(height: 22),

                    // 2. الفصل الدراسي (Semester)
                    Text(
                      'الفصل الدراسي',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: tokens.textHigh,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildSemesterSelector(),

                    const SizedBox(height: 24),

                    // 3. Live Preview Card (قائمة المقررات المعتمدة)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'المقررات المقررة (معاينة حية)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: tokens.textHigh,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: tokens.brandContainer.withValues(alpha: 0.5),
                            borderRadius: AppRadii.fullRadius,
                          ),
                          child: Text(
                            '$yearName • $semesterName (${previewCourses.length} مواد)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: tokens.brand,
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
                color: tokens.surface,
                border: Border(top: BorderSide(color: tokens.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brand,
                    foregroundColor: tokens.onBrand,
                    disabledBackgroundColor: tokens.brand.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, color: tokens.onBrand, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'تأكيد وإضافة المواد',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: tokens.onBrand,
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
    final tokens = context.tokens;

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
          borderRadius: AppRadii.controlRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? tokens.brandContainer.withValues(alpha: 0.45)
                  : tokens.surface,
              borderRadius: AppRadii.controlRadius,
              border: Border.all(
                color: isSelected ? tokens.brand : tokens.border,
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isSelected ? tokens.brand : tokens.surfaceAlt,
                  child: Text(
                    '$id',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? tokens.onBrand : tokens.textMedium,
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
                          color: isSelected ? tokens.brand : tokens.textHigh,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        sub,
                        style: TextStyle(
                          fontSize: 10,
                          color: tokens.textLow,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: tokens.brand, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  /// أزرار اختيار الفصل الدراسي (الترم الأول أو الثاني)
  Widget _buildSemesterSelector() {
    final tokens = context.tokens;

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
              borderRadius: AppRadii.controlRadius,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? tokens.brandContainer.withValues(alpha: 0.45)
                      : tokens.surface,
                  borderRadius: AppRadii.controlRadius,
                  border: Border.all(
                    color: isSelected ? tokens.brand : tokens.border,
                    width: isSelected ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected ? tokens.brand : tokens.textMedium,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? tokens.brand : tokens.textHigh,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle_rounded, color: tokens.brand, size: 16),
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
    final tokens = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: tokens.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: courses.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: tokens.border),
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textHigh,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // كود المادة
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tokens.surfaceAlt,
                    borderRadius: AppRadii.controlRadius,
                  ),
                  child: Text(
                    course.code,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: tokens.textMedium,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // الساعات المعتمدة
                Text(
                  course.creditHours == 2 ? 'ساعتان' : '${course.creditHours} س',
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textLow,
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
