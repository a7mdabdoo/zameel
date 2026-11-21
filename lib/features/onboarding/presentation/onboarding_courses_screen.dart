// مطور 2
// فيجما: التهيئة: اختيار وإضافة المواد وتحديد الساعات المعتمدة - ذاكر وعلّم

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_tokens.dart';

class OnboardingCoursesScreen extends StatefulWidget {
  const OnboardingCoursesScreen({super.key});

  @override
  State<OnboardingCoursesScreen> createState() => _OnboardingCoursesScreenState();
}

class _OnboardingCoursesScreenState extends State<OnboardingCoursesScreen> {
  // قائمة المواد المتاحة (تبدأ بالمواد المقترحة ثم يدعم إضافة مواد جديدة بحرية)
  late List<CourseSeed> _allCourses;
  late Set<String> _selectedCourseIds;

  @override
  void initState() {
    super.initState();
    _allCourses = List<CourseSeed>.from(AppConstants.seedCourses);
    _selectedCourseIds = _allCourses.map((c) => c.id).toSet();
  }

  void _showAddCourseDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    int selectedCreditHours = 3; // الافتراضي 3 ساعات معتمدة (أهمية أعلى)

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final tokens = ctx.tokens;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: AppRadii.sheetTopRadius,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'إضافة مادة دراسية جديدة',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tokens.textHigh),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: tokens.textMedium),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'أضف مقرراً مسجلاً في جدولك مع تحديد عدد ساعاته لحساب أهميته في جدول المذاكرة.',
                      style: TextStyle(fontSize: 12, color: tokens.textMedium),
                    ),
                    const SizedBox(height: 20),

                    // Course Name
                    Text('اسم المادة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textHigh)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'مثال: الذكاء الاصطناعي، شبكات الحاسب...',
                        filled: true,
                        fillColor: tokens.surfaceAlt,
                        border: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide(color: tokens.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide(color: tokens.border)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Course Code
                    Text('كود المادة (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textHigh)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: codeController,
                      decoration: InputDecoration(
                        hintText: 'مثال: AI201 أو NET202',
                        filled: true,
                        fillColor: tokens.surfaceAlt,
                        border: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide(color: tokens.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide(color: tokens.border)),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Credit Hours Selection
                    Text(
                      'عدد الساعات المعتمدة للمادة (الأهمية الأكاديمية)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textHigh),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildHourOption(
                          tokens: tokens,
                          hours: 2,
                          label: 'ساعتان (2h)',
                          subtitle: 'أهمية عادية',
                          selected: selectedCreditHours == 2,
                          onTap: () => setModalState(() => selectedCreditHours = 2),
                        ),
                        const SizedBox(width: 8),
                        _buildHourOption(
                          tokens: tokens,
                          hours: 3,
                          label: '3 ساعات (3h)',
                          subtitle: 'أهمية عالية',
                          selected: selectedCreditHours == 3,
                          onTap: () => setModalState(() => selectedCreditHours = 3),
                        ),
                        const SizedBox(width: 8),
                        _buildHourOption(
                          tokens: tokens,
                          hours: 4,
                          label: '4 ساعات (4h)',
                          subtitle: 'أهمية قصوى',
                          selected: selectedCreditHours == 4,
                          onTap: () => setModalState(() => selectedCreditHours = 4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Weight Explanation Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.brandContainer.withValues(alpha: 0.35),
                        borderRadius: AppRadii.controlRadius,
                        border: Border.all(color: tokens.brand.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18, color: tokens.brand),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedCreditHours >= 3
                                  ? 'المادة ذات الـ $selectedCreditHours ساعات ستحظى بأولوية وتكرار أكبر بنسبة ${(selectedCreditHours / 2.0 * 100 - 100).round()}% في خطة المذاكرة مقارنة بالمواد ذات الساعتين.'
                                  : 'المادة ذات الساعتين ستحصل على وزن مذاكرة قياسي متوازن مع باقي المقررات.',
                              style: TextStyle(fontSize: 11, color: tokens.brand, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('يرجى إدخال اسم المادة')),
                            );
                            return;
                          }

                          final cleanCode = codeController.text.trim().isEmpty
                              ? 'GEN${_allCourses.length + 1}'
                              : codeController.text.trim().toUpperCase();

                          final newCourse = CourseSeed(
                            id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                            name: name,
                            code: cleanCode,
                            color: tokens.brand,
                            creditHours: selectedCreditHours,
                          );

                          setState(() {
                            _allCourses.add(newCourse);
                            _selectedCourseIds.add(newCourse.id);
                          });

                          Navigator.pop(ctx);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تمت إضافة مادة "$name" ($selectedCreditHours ساعات معتمدة) بنجاح.'),
                            ),
                          );
                        },
                        icon: Icon(Icons.add_task_rounded, color: tokens.onBrand),
                        label: Text(
                          'إضافة المادة واختيارها',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tokens.onBrand),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.brand,
                          shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHourOption({
    required AppTokens tokens,
    required int hours,
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? tokens.brandContainer.withValues(alpha: 0.6) : tokens.surfaceAlt,
            borderRadius: AppRadii.controlRadius,
            border: Border.all(
              color: selected ? tokens.brand : tokens.border,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                  color: selected ? tokens.brand : tokens.textHigh,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 9,
                  color: selected ? tokens.brand : tokens.textMedium,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        title: Text(
          'الخطوة 2 من 3',
          style: TextStyle(fontSize: 14, color: tokens.textMedium, fontWeight: FontWeight.w600),
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
                      Expanded(child: Container(height: 4, decoration: BoxDecoration(color: tokens.brand, borderRadius: AppRadii.controlRadius))),
                      const SizedBox(width: 6),
                      Expanded(child: Container(height: 4, decoration: BoxDecoration(color: tokens.brand, borderRadius: AppRadii.controlRadius))),
                      const SizedBox(width: 6),
                      Expanded(child: Container(height: 4, decoration: BoxDecoration(color: tokens.border, borderRadius: AppRadii.controlRadius))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'اختر مواد الفصل الدراسي',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: tokens.textHigh),
                        ),
                      ),
                      // زر إضافة مادة مخصصة
                      TextButton.icon(
                        onPressed: _showAddCourseDialog,
                        icon: Icon(Icons.add_circle_outline_rounded, size: 20, color: tokens.brand),
                        label: Text(
                          'أضف مادة',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.brand),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'حدد موادك المقررة أو أضف موادك الخاصة (${_selectedCourseIds.length} محددة)',
                    style: TextStyle(fontSize: 13, color: tokens.textMedium),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // Courses list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                itemCount: _allCourses.length,
                itemBuilder: (context, index) {
                  final course = _allCourses[index];
                  final isSelected = _selectedCourseIds.contains(course.id);
                  final isHighPriority = course.creditHours >= 3;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: AppRadii.controlRadius,
                      border: Border.all(
                        color: isSelected ? course.color : tokens.border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: course.color.withValues(alpha: 0.15),
                          borderRadius: AppRadii.controlRadius,
                        ),
                        child: Center(
                          child: Text(
                            course.code.length >= 2 ? course.code.substring(0, 2) : course.code,
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
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.textHigh),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Text(
                              course.code,
                              style: TextStyle(fontSize: 12, color: tokens.textMedium),
                            ),
                            const SizedBox(width: 8),
                            // شارة عدد الساعات المعتمدة ومستوى الأهمية
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isHighPriority
                                      ? tokens.warningContainer
                                      : tokens.surfaceAlt,
                                  borderRadius: AppRadii.controlRadius,
                                  border: Border.all(
                                    color: isHighPriority
                                        ? tokens.warning.withValues(alpha: 0.4)
                                        : tokens.border,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isHighPriority) ...[
                                      Icon(Icons.star_rounded, size: 12, color: tokens.warning),
                                      const SizedBox(width: 3),
                                    ],
                                    Flexible(
                                      child: Text(
                                        '${course.creditHours} ساعات معتمدة${isHighPriority ? ' (أهمية أعلى)' : ''}',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isHighPriority ? FontWeight.bold : FontWeight.w500,
                                          color: isHighPriority ? tokens.warning : tokens.textMedium,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: Checkbox(
                        value: isSelected,
                        activeColor: course.color,
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
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
                      : () {
                          final selectedCourses = _allCourses
                              .where((c) => _selectedCourseIds.contains(c.id))
                              .toList();
                          context.push('/onboarding-rate', extra: selectedCourses);
                        },
                  icon: Icon(Icons.arrow_back_rounded, color: tokens.onBrand, size: 20),
                  label: Text(
                    'التالي: تقييم مستواك',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.onBrand),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brand,
                    disabledBackgroundColor: tokens.brand.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
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
