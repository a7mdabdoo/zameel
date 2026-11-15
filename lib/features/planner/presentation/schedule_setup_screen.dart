// مطور 3
// شاشة إعداد وتخصيص جدول المحاضرات الأسبوعي يدوياً وبناء خطة المذاكرة الذكية بناءً عليه

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/app_models.dart';
import '../../../core/state/app_state.dart';
import '../../auth/data/auth_service.dart';

class ScheduleSetupScreen extends ConsumerStatefulWidget {
  const ScheduleSetupScreen({super.key});

  @override
  ConsumerState<ScheduleSetupScreen> createState() => _ScheduleSetupScreenState();
}

class _ScheduleSetupScreenState extends ConsumerState<ScheduleSetupScreen> {
  final List<String> _days = ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
  final List<String> _commonStartTimes = [
    '08:30 ص',
    '09:00 ص',
    '10:00 ص',
    '10:30 ص',
    '11:30 ص',
    '12:00 م',
    '01:00 م',
    '01:30 م',
    '02:30 م',
    '03:00 م',
    '04:00 م',
  ];
  final List<String> _commonEndTimes = [
    '10:00 ص',
    '10:30 ص',
    '11:30 ص',
    '12:00 م',
    '01:00 م',
    '01:30 م',
    '02:30 م',
    '03:00 م',
    '04:00 م',
    '05:00 م',
  ];

  late List<ScheduleItemModel> _lectures;
  String _selectedDay = 'السبت';
  CourseSeed? _selectedCourse;
  String _startTime = '09:00 ص';
  String _endTime = '10:30 ص';
  final TextEditingController _roomController = TextEditingController(text: 'قاعة 3');
  bool _isInitialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  void _initLectures(List<CourseSeed> availableCourses) {
    if (_isInitialized) return;
    final plannerState = ref.read(plannerProvider);
    _lectures = List<ScheduleItemModel>.from(plannerState.lectureSchedule);
    if (availableCourses.isNotEmpty) {
      _selectedCourse = availableCourses.first;
    }
    _isInitialized = true;
  }

  List<CourseSeed> _getAvailableCourses(Map<String, dynamic>? userDoc) {
    if (userDoc == null) return List<CourseSeed>.from(AppConstants.seedCourses);
    final coursesData = userDoc['coursesData'] as List<dynamic>?;
    if (coursesData != null && coursesData.isNotEmpty) {
      return coursesData
          .map((m) => CourseSeed.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    }
    final selectedIds = List<String>.from(userDoc['selectedCourses'] ?? []);
    if (selectedIds.isNotEmpty) {
      final list = AppConstants.seedCourses.where((c) => selectedIds.contains(c.id)).toList();
      if (list.isNotEmpty) return list;
    }
    return List<CourseSeed>.from(AppConstants.seedCourses);
  }

  void _addLectureToList() {
    if (_selectedCourse == null) return;
    final room = _roomController.text.trim().isEmpty ? 'قاعة عامة' : _roomController.text.trim();

    final newLecture = ScheduleItemModel(
      id: 'lec_${DateTime.now().millisecondsSinceEpoch}',
      courseName: _selectedCourse!.name,
      courseCode: _selectedCourse!.code,
      day: _selectedDay,
      startTime: _startTime,
      endTime: _endTime,
      room: room,
      color: _selectedCourse!.color,
    );

    setState(() {
      _lectures.add(newLecture);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تمت إضافة محاضرة "${_selectedCourse!.name}" ليوم $_selectedDay'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _removeLecture(int index) {
    final removed = _lectures[index];
    setState(() {
      _lectures.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حذف محاضرة "${removed.courseName}"'),
        backgroundColor: AppColors.textSecondary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveAllAndGeneratePlan(List<CourseSeed> courses) async {
    setState(() => _isSaving = true);

    // 1. تحديث جدول المحاضرات وإعادة توليد خطة المذاكرة حولها
    ref.read(plannerProvider.notifier).setLecturesAndRegeneratePlan(
      _lectures,
      courses: courses,
    );

    // 2. الحفظ في فايربيس
    try {
      await ref.read(authServiceProvider).updateUserProfile(
        lecturesData: _lectures.map((l) => l.toMap()).toList(),
      );
    } catch (e) {
      debugPrint('Error saving lectures to firestore: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ (${_lectures.length}) محاضرات وإعادة ضبط خطة المذاكرة الذكية بنجاح! ⚡'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final userDoc = userProfileAsync.value?.data();
    final availableCourses = _getAvailableCourses(userDoc);
    _initLectures(availableCourses);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final surfaceAlt = isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt;
    final hairline = isDark ? AppColors.darkHairline : AppColors.hairline;
    final onSurface = theme.colorScheme.onSurface;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final primaryContainer = isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'جدول المحاضرات والمذاكرة 🗓️',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: onSurface),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // بطاقة المقدمة
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor.withValues(alpha: 0.12), cardColor],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, color: primaryColor, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'أدخل جدول محاضراتك بنفسك',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'أضف أوقات المحاضرات الأسبوعية، وستقوم الخوارزمية الذكية بتفادي أوقات انشغالك وتوزيع جلسات المذاكرة وفق أهمية وساعات كل مادة.',
                      style: TextStyle(fontSize: 12, color: textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // بطاقة إضافة محاضرة جديدة
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: hairline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded, color: primaryColor, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'إضافة محاضرة للجدول ➕',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: onSurface),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // اختيار اليوم
                    Text('اليوم', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: onSurface)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: hairline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDay,
                          isExpanded: true,
                          dropdownColor: cardColor,
                          items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d, style: TextStyle(fontSize: 13, color: onSurface)))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedDay = val);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // اختيار المادة من مواد المستخدم
                    Text('المادة الدراسية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: onSurface)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: hairline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<CourseSeed>(
                          value: _selectedCourse ?? (availableCourses.isNotEmpty ? availableCourses.first : null),
                          isExpanded: true,
                          dropdownColor: cardColor,
                          items: availableCourses.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${c.name} (${c.creditHours} ساعات)',
                                      style: TextStyle(fontSize: 13, color: onSurface),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCourse = val);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // أوقات المحاضرة (من - إلى)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('من الساعة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: onSurface)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: surfaceAlt,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: hairline),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _startTime,
                                    isExpanded: true,
                                    dropdownColor: cardColor,
                                    items: _commonStartTimes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontSize: 12, color: onSurface)))).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _startTime = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('إلى الساعة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: onSurface)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: surfaceAlt,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: hairline),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _endTime,
                                    isExpanded: true,
                                    dropdownColor: cardColor,
                                    items: _commonEndTimes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontSize: 12, color: onSurface)))).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _endTime = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // القاعة / المكان
                    Text('القاعة أو المعمل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: onSurface)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _roomController,
                      style: TextStyle(color: onSurface),
                      decoration: InputDecoration(
                        hintText: 'قاعة 3، مدرج 1، معمل 2...',
                        hintStyle: TextStyle(color: textSecondary),
                        filled: true,
                        fillColor: surfaceAlt,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairline)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairline)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // زر الإضافة
                    ElevatedButton.icon(
                      onPressed: _addLectureToList,
                      icon: const Icon(Icons.add, color: Colors.white, size: 18),
                      label: const Text('إضافة هذه المحاضرة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // قائمة المحاضرات المضافة
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'المحاضرات المجدولة (${_lectures.length})',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onSurface),
                  ),
                  if (_lectures.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _lectures.clear()),
                      child: const Text('مسح الكل', style: TextStyle(fontSize: 12, color: AppColors.error)),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (_lectures.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: hairline),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.event_busy_rounded, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary, size: 36),
                        const SizedBox(height: 8),
                        Text(
                          'لا توجد محاضرات مضافة حتى الآن',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'أضف مواعيدك بالنموذج أعلاه لبناء خطة المذاكرة حولها',
                          style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._lectures.asMap().entries.map((entry) {
                  final index = entry.key;
                  final lecture = entry.value;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: hairline),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 46,
                          decoration: BoxDecoration(
                            color: lecture.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: primaryContainer.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      lecture.day,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryColor),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      lecture.courseName,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: onSurface),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${lecture.startTime} – ${lecture.endTime} • ${lecture.room}',
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                          onPressed: () => _removeLecture(index),
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 24),

              // زر الحفظ والتوليد النهائي
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : () => _saveAllAndGeneratePlan(availableCourses),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                  label: Text(
                    _isSaving ? 'جارٍ توليد الخطة الذكية...' : 'حفظ وتوليد جدول المذاكرة الذكي ⚡',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
