// مطور 3
// فيجما: إعداد جدول المحاضرات والمذاكرة الأسبوعية الذكية - ذاكر وعلّم

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_tokens.dart';
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
  String _selectedDay = 'السبت';
  String? _selectedCourseId;
  CourseSeed? _selectedCourse;

  final TextEditingController _roomController = TextEditingController(text: 'قاعة 3');

  String _startTime = '09:00 ص';
  String _endTime = '11:00 ص';

  final List<String> _commonStartTimes = [
    '08:00 ص', '08:30 ص', '09:00 ص', '09:30 ص', '10:00 ص', '10:30 ص',
    '11:00 ص', '11:30 ص', '12:00 م', '12:30 م', '01:00 م', '01:30 م',
    '02:00 م', '02:30 م', '03:00 م', '03:30 م', '04:00 م',
  ];

  final List<String> _commonEndTimes = [
    '09:00 ص', '09:30 ص', '10:00 ص', '10:30 ص', '11:00 ص', '11:30 ص',
    '12:00 م', '12:30 م', '01:00 م', '01:30 م', '02:00 م', '02:30 م',
    '03:00 م', '03:30 م', '04:00 م', '04:30 م', '05:00 م', '06:00 م',
  ];

  List<ScheduleItemModel> _lectures = [];
  bool _isSaving = false;
  bool _isInitialized = false;

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  void _initLectures(List<CourseSeed> courses) {
    if (_isInitialized) return;
    _isInitialized = true;

    final plannerState = ref.read(plannerProvider);
    if (plannerState.lectureSchedule.isNotEmpty) {
      _lectures = List<ScheduleItemModel>.from(plannerState.lectureSchedule);
    } else {
      _lectures = [];
    }
  }

  List<CourseSeed> _getAvailableCourses(Map<String, dynamic>? userDoc) {
    if (userDoc != null && userDoc['coursesData'] != null) {
      final rawList = userDoc['coursesData'] as List<dynamic>;
      final list = rawList
          .whereType<Map<String, dynamic>>()
          .map((m) => CourseSeed.fromMap(m))
          .toList();
      if (list.isNotEmpty) return list;
    }
    return AppConstants.seedCourses;
  }

  int _parseTimeToMinutes(String timeStr) {
    // تنسيق: "09:00 ص" أو "01:30 م"
    try {
      final parts = timeStr.trim().split(' ');
      final hm = parts[0].split(':');
      var h = int.parse(hm[0]);
      final m = int.parse(hm[1]);
      final isPm = parts.length > 1 && parts[1].contains('م');
      if (isPm && h != 12) h += 12;
      if (!isPm && h == 12) h = 0;
      return h * 60 + m;
    } catch (_) {
      return 0;
    }
  }

  void _addLectureToList() {
    final tokens = context.tokens;
    if (_selectedCourse == null) return;

    // Rule 1: No Duplicate Course in the Entire Weekly Schedule
    final existingLecture = _lectures.where(
      (l) => l.courseCode == _selectedCourse!.code || l.courseName == _selectedCourse!.name
    ).firstOrNull;
    if (existingLecture != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لقد قمت بإضافة محاضرة لمادة "${_selectedCourse!.name}" مسبقاً (يوم ${existingLecture.day}). لا يمكن تكرار نفس المادة في جدول الأسبوع.'),
          backgroundColor: tokens.danger,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Rule 2: No Time Overlaps on the Same Day
    final newStartMin = _parseTimeToMinutes(_startTime);
    final newEndMin = _parseTimeToMinutes(_endTime);

    if (newEndMin <= newStartMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('وقت انتهاء المحاضرة يجب أن يكون بعد وقت البدء.'),
          backgroundColor: tokens.warning,
        ),
      );
      return;
    }

    final hasConflict = _lectures.any((l) {
      if (l.day != _selectedDay) return false;
      final lStart = _parseTimeToMinutes(l.startTime);
      final lEnd = _parseTimeToMinutes(l.endTime);
      return newStartMin < lEnd && lStart < newEndMin;
    });

    if (hasConflict) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يوجد تعارض في التوقيت مع محاضرة أخرى مسجلة في يوم $_selectedDay.'),
          backgroundColor: tokens.warning,
        ),
      );
      return;
    }

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
        backgroundColor: tokens.brand,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _removeLecture(int index) {
    final tokens = context.tokens;
    final removed = _lectures[index];
    setState(() {
      _lectures.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حذف محاضرة "${removed.courseName}"'),
        backgroundColor: tokens.surfaceAlt,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveAllAndGeneratePlan(List<CourseSeed> courses) async {
    final tokens = context.tokens;
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
          content: Text('تم حفظ (${_lectures.length}) محاضرات وضبط خطة المذاكرة بنجاح.'),
          backgroundColor: tokens.success,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final userDoc = userProfileAsync.value?.data();
    final availableCourses = _getAvailableCourses(userDoc);
    _initLectures(availableCourses);

    final safeSelectedCourseId = availableCourses.any((c) => c.id == _selectedCourseId)
        ? _selectedCourseId
        : (availableCourses.isNotEmpty ? availableCourses.first.id : null);
    _selectedCourseId = safeSelectedCourseId;
    _selectedCourse = (safeSelectedCourseId != null && availableCourses.isNotEmpty)
        ? availableCourses.firstWhere((c) => c.id == safeSelectedCourseId, orElse: () => availableCourses.first)
        : null;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: tokens.textHigh),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'جدول المحاضرات والمذاكرة',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: tokens.textHigh),
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
                    colors: [tokens.brand.withValues(alpha: 0.12), tokens.surface],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: tokens.brand.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, color: tokens.brand, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'أدخل جدول محاضراتك بنفسك',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tokens.brand),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'أضف أوقات المحاضرات الأسبوعية، وستقوم الخوارزمية الذكية بتفادي أوقات انشغالك وتوزيع جلسات المذاكرة وفق أهمية وساعات كل مادة.',
                      style: TextStyle(fontSize: 12, color: tokens.textMedium, height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // بطاقة إضافة محاضرة جديدة
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: tokens.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded, color: tokens.brand, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'إضافة محاضرة للجدول',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tokens.textHigh),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // اختيار اليوم
                    Text('اليوم', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tokens.textHigh)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: tokens.surfaceAlt,
                        borderRadius: AppRadii.controlRadius,
                        border: Border.all(color: tokens.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDay,
                          isExpanded: true,
                          dropdownColor: tokens.surface,
                          items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d, style: TextStyle(fontSize: 13, color: tokens.textHigh)))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedDay = val);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // اختيار المادة من مواد المستخدم
                    Text('المادة الدراسية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tokens.textHigh)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: tokens.surfaceAlt,
                        borderRadius: AppRadii.controlRadius,
                        border: Border.all(color: tokens.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: safeSelectedCourseId,
                          isExpanded: true,
                          dropdownColor: tokens.surface,
                          items: availableCourses.map((c) {
                            return DropdownMenuItem<String>(
                              value: c.id,
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
                                      style: TextStyle(fontSize: 13, color: tokens.textHigh),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCourseId = val;
                                _selectedCourse = availableCourses.firstWhere(
                                  (c) => c.id == val,
                                  orElse: () => availableCourses.first,
                                );
                              });
                            }
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
                              Text('من الساعة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tokens.textHigh)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: tokens.surfaceAlt,
                                  borderRadius: AppRadii.controlRadius,
                                  border: Border.all(color: tokens.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _startTime,
                                    isExpanded: true,
                                    dropdownColor: tokens.surface,
                                    items: _commonStartTimes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontSize: 12, color: tokens.textHigh)))).toList(),
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
                              Text('إلى الساعة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tokens.textHigh)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: tokens.surfaceAlt,
                                  borderRadius: AppRadii.controlRadius,
                                  border: Border.all(color: tokens.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _endTime,
                                    isExpanded: true,
                                    dropdownColor: tokens.surface,
                                    items: _commonEndTimes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontSize: 12, color: tokens.textHigh)))).toList(),
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
                    Text('القاعة أو المعمل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tokens.textHigh)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _roomController,
                      style: TextStyle(color: tokens.textHigh),
                      decoration: InputDecoration(
                        hintText: 'قاعة 3، مدرج 1، معمل 2...',
                        hintStyle: TextStyle(color: tokens.textMedium),
                        filled: true,
                        fillColor: tokens.surfaceAlt,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide(color: tokens.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide(color: tokens.border)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // زر الإضافة
                    ElevatedButton.icon(
                      onPressed: _addLectureToList,
                      icon: Icon(Icons.add, color: tokens.onBrand, size: 18),
                      label: Text('إضافة هذه المحاضرة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.onBrand)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brand,
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textHigh),
                  ),
                  if (_lectures.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _lectures.clear()),
                      child: Text('مسح الكل', style: TextStyle(fontSize: 12, color: tokens.danger)),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (_lectures.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: AppRadii.cardRadius,
                    border: Border.all(color: tokens.border),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.event_busy_rounded, color: tokens.textLow, size: 36),
                        const SizedBox(height: 8),
                        Text(
                          'لا توجد محاضرات مضافة حتى الآن',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.textMedium),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'أضف مواعيدك بالنموذج أعلاه لبناء خطة المذاكرة حولها',
                          style: TextStyle(fontSize: 12, color: tokens.textLow),
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
                      color: tokens.surface,
                      borderRadius: AppRadii.controlRadius,
                      border: Border.all(color: tokens.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 46,
                          decoration: BoxDecoration(
                            color: lecture.color,
                            borderRadius: AppRadii.controlRadius,
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
                                      color: tokens.brandContainer.withValues(alpha: 0.6),
                                      borderRadius: AppRadii.controlRadius,
                                    ),
                                    child: Text(
                                      lecture.day,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tokens.brand),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      lecture.courseName,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textHigh),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${lecture.startTime} – ${lecture.endTime} • ${lecture.room}',
                                style: TextStyle(fontSize: 11, color: tokens.textMedium),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: tokens.danger, size: 20),
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
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: tokens.onBrand),
                        )
                      : Icon(Icons.auto_awesome_rounded, color: tokens.onBrand),
                  label: Text(
                    _isSaving ? 'جارٍ توليد الخطة...' : 'حفظ وتوليد خطة المذاكرة',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tokens.onBrand),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brand,
                    foregroundColor: tokens.onBrand,
                    shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
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