// مطور 2
// فيجما: حسابي - ذاكر وعلّم

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_service.dart';
import '../../../core/state/app_state.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final user = ref.watch(authServiceProvider).currentUser;
    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final userDoc = userProfileAsync.value?.data();
    final plannerLectures = ref.watch(plannerProvider).lectureSchedule;

    // جلب البيانات الحقيقية للمستخدم المسجل حالياً من فايربيس
    final userName = (userDoc?['name'] as String?)?.isNotEmpty == true
        ? (userDoc!['name'] as String)
        : (user?.displayName?.isNotEmpty == true
            ? user!.displayName!
            : (user?.email?.split('@').first ?? 'طالب زميل'));

    final userEmail = user?.email ?? '';

    final faculty = userDoc?['faculty'] as String? ?? AppConstants.faculty;
    final year = userDoc?['year'] as String? ?? AppConstants.academicYear;
    final department = userDoc?['department'] as String? ?? 'عام (General)';
    final completedSessions = (userDoc?['completedSessions'] as num?)?.toInt() ?? 0;
    final teacherRating = (userDoc?['teacherRating'] as num?)?.toDouble() ?? 5.0;
    final studyHours = (userDoc?['studyHours'] as num?)?.toInt() ?? 0;

    // استخراج المواد الدراسية وتقييمات الطالب من فايربيس
    final userCourses = _getUserCourses(userDoc);
    final userRatings = _getUserRatings(userDoc, userCourses);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'الملف الشخصي 👤',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.hairline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(
                        userName.isNotEmpty ? userName.substring(0, 1) : 'أ',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userEmail,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$faculty • $year • $department',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Academic Badges & Stats
              Row(
                children: [
                  Expanded(
                    child: _buildBadgeCard('جلسات مكتملة', '$completedSessions جلسة', Icons.check_circle_outline, AppColors.deepSage),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBadgeCard('تقييم كمعلم', '${teacherRating.toStringAsFixed(1)} ★', Icons.star_outline_rounded, AppColors.pointsAmber),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBadgeCard('ساعات المذاكرة', '$studyHours ساعة', Icons.timer_outlined, AppColors.primary),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Courses Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _showAddCourseModal(context, userCourses, userRatings),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primary),
                        label: const Text(
                          'أضف مادة',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showManageCoursesModal(context, userCourses, userRatings),
                        icon: const Icon(Icons.tune_rounded, size: 18, color: AppColors.textSecondary),
                        label: const Text(
                          'تعديل',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'موادي الدراسية 📚 (${userCourses.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Course Cards List in Profile
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < userCourses.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: AppColors.hairline),
                      _buildCourseRow(userCourses[i], userRatings[userCourses[i].id] ?? 2),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // جدول المحاضرات الأسبوعية
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => context.push('/schedule-setup'),
                    icon: const Icon(Icons.tune_rounded, size: 16, color: AppColors.primary),
                    label: const Text('إعداد وتعديل 🗓️', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                  Text(
                    'جدول محاضراتي 🗓️ (${plannerLectures.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: plannerLectures.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () => context.push('/schedule-setup'),
                            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                            label: const Text('أضف جدول محاضراتك لتوليد خطة المذاكرة الذكية', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (int i = 0; i < plannerLectures.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: AppColors.hairline),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: plannerLectures[i].color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          plannerLectures[i].courseName,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${plannerLectures[i].day} • ${plannerLectures[i].startTime} – ${plannerLectures[i].endTime} • ${plannerLectures[i].room}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
              ),

              const SizedBox(height: 24),

              // Settings List
              const Text(
                'إعدادات التطبيق ⚙️',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('الوضع الليلي (Dark Theme)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('تبديل مظهر الشاشات للألوان الداكنة', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      secondary: const Icon(Icons.dark_mode_outlined, color: AppColors.primary),
                      value: isDark,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) {
                        ref.read(themeModeProvider.notifier).toggleTheme(val);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(val ? 'تم تفعيل الوضع الداكن بنجاح 🌙' : 'تم تفعيل الوضع الفاتح بنجاح ☀️')),
                        );
                      },
                    ),
                    const Divider(height: 1, color: AppColors.hairline),
                    SwitchListTile(
                      title: const Text('تنبيهات المذاكرة والجلسات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('إشعارات قبل بدء المواعيد بـ 15 دقيقة', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      secondary: const Icon(Icons.notifications_none_rounded, color: AppColors.primary),
                      value: _notifications,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) => setState(() => _notifications = val),
                    ),
                    const Divider(height: 1, color: AppColors.hairline),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.textSecondary),
                      title: const Text('سياسة الخصوصية وبنك الساعات', style: TextStyle(fontSize: 14)),
                      trailing: const Icon(Icons.arrow_back_ios_rounded, size: 14, color: AppColors.textTertiary),
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Sign Out Button -> /welcome
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) {
                    context.go('/welcome');
                  }
                },
                icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                label: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  List<CourseSeed> _getUserCourses(Map<String, dynamic>? userDoc) {
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

  Map<String, int> _getUserRatings(Map<String, dynamic>? userDoc, List<CourseSeed> courses) {
    final raw = userDoc?['courseRatings'] as Map<dynamic, dynamic>?;
    final map = <String, int>{};
    if (raw != null) {
      raw.forEach((k, v) {
        if (v is num) map[k.toString()] = v.toInt();
      });
    }
    for (final c in courses) {
      map.putIfAbsent(c.id, () => 2);
    }
    return map;
  }

  Widget _buildCourseRow(CourseSeed course, int rating) {
    String ratingLabel;
    Color ratingColor;
    switch (rating) {
      case 1:
        ratingLabel = 'أحتاج مساعدة';
        ratingColor = Colors.orange.shade700;
        break;
      case 3:
        ratingLabel = 'مستعد للشرح';
        ratingColor = AppColors.deepSage;
        break;
      case 2:
      default:
        ratingLabel = 'متوسط';
        ratingColor = AppColors.primary;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: course.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  course.code,
                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: course.creditHours >= 3 ? AppColors.pointsAmber.withValues(alpha: 0.15) : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${course.creditHours} ساعات',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: course.creditHours >= 3 ? const Color(0xFF664700) : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ratingColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              ratingLabel,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ratingColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCourseModal(
    BuildContext context,
    List<CourseSeed> currentCourses,
    Map<String, int> currentRatings,
  ) {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    int selectedCreditHours = 3;
    int selectedRating = 2;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'إضافة مادة جديدة لحسابي ➕',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'ستتم إضافتها إلى خطة مذاكرتك وبنك الوقت مع زملائك',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),

                  // Course Name
                  const Text('اسم المادة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'مثال: الذكاء الاصطناعي (AI)',
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.book_outlined, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Course Code
                  const Text('كود المادة (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      hintText: 'مثال: AI301',
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Credit Hours
                  const Text('الساعات المعتمدة للمادة (الأهمية)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildHourChoice(
                        hours: 2,
                        label: 'ساعتان (2h)',
                        subtitle: 'وزن أساسي',
                        selected: selectedCreditHours == 2,
                        onTap: () => setModalState(() => selectedCreditHours = 2),
                      ),
                      const SizedBox(width: 8),
                      _buildHourChoice(
                        hours: 3,
                        label: '3 ساعات (3h)',
                        subtitle: 'أولوية أعلى ⭐',
                        selected: selectedCreditHours == 3,
                        onTap: () => setModalState(() => selectedCreditHours = 3),
                      ),
                      const SizedBox(width: 8),
                      _buildHourChoice(
                        hours: 4,
                        label: '4 ساعات (4h)',
                        subtitle: 'أولوية قصوى 🔥',
                        selected: selectedCreditHours == 4,
                        onTap: () => setModalState(() => selectedCreditHours = 4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Rating in this course
                  const Text('تقييم مستواك في المادة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildRateChip('أحتاج مساعدة', 1, selectedRating == 1, Colors.orange.shade700, () {
                        setModalState(() => selectedRating = 1);
                      }),
                      const SizedBox(width: 8),
                      _buildRateChip('متوسط', 2, selectedRating == 2, AppColors.primary, () {
                        setModalState(() => selectedRating = 2);
                      }),
                      const SizedBox(width: 8),
                      _buildRateChip('مستعد للشرح', 3, selectedRating == 3, AppColors.deepSage, () {
                        setModalState(() => selectedRating = 3);
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Save CTA
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى إدخال اسم المادة الدراسية')),
                          );
                          return;
                        }

                        setModalState(() => isSaving = true);

                        final code = codeController.text.trim().isEmpty
                            ? 'CRS${DateTime.now().millisecondsSinceEpoch % 1000}'
                            : codeController.text.trim().toUpperCase();

                        final newId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
                        final newCourse = CourseSeed(
                          id: newId,
                          name: name,
                          code: code,
                          color: AppColors.courseTeal,
                          creditHours: selectedCreditHours,
                        );

                        final updatedCourses = [...currentCourses, newCourse];
                        final updatedRatings = Map<String, int>.from(currentRatings);
                        updatedRatings[newId] = selectedRating;

                        // تحديث خوارزمية المذاكرة في الذاكرة الحية فوراً
                        ref.read(plannerProvider.notifier).updateCoursesAndRegeneratePlan(
                          updatedCourses,
                          updatedRatings,
                        );

                        // الحفظ في فايربيس بشكل آمن
                        try {
                          await ref.read(authServiceProvider).updateUserProfile(
                            selectedCourses: updatedCourses.map((c) => c.id).toList(),
                            coursesData: updatedCourses.map((c) => c.toMap()).toList(),
                            courseRatings: updatedRatings,
                          );
                        } catch (e) {
                          debugPrint('Add course error: $e');
                        }

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تمت إضافة مادة "$name" ($selectedCreditHours ساعات) لحسابك وتحديث الخطة بنجاح 🎉'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                      icon: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.add_task_rounded, color: Colors.white),
                      label: Text(
                        isSaving ? 'جارٍ الحفظ...' : 'إضافة المادة وحفظها',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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
          );
        },
      ),
    );
  }

  void _showManageCoursesModal(
    BuildContext context,
    List<CourseSeed> currentCourses,
    Map<String, int> currentRatings,
  ) {
    List<CourseSeed> editableCourses = List<CourseSeed>.from(currentCourses);
    Map<String, int> editableRatings = Map<String, int>.from(currentRatings);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'تعديل المواد المقررة والتقييمات ✏️',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'يمكنك تعديل تقييمك وساعات كل مادة أو حذفها، وسيتم تحديث جدول مذاكرتك وبنك الوقت فوراً',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: ListView.builder(
                    itemCount: editableCourses.length,
                    itemBuilder: (context, index) {
                      final course = editableCourses[index];
                      final rating = editableRatings[course.id] ?? 2;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(color: course.color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    course.name,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: course.creditHours >= 3 ? AppColors.pointsAmber.withValues(alpha: 0.2) : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${course.creditHours} ساعات',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: course.creditHours >= 3 ? const Color(0xFF664700) : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                if (editableCourses.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                    onPressed: () {
                                      setModalState(() {
                                        editableCourses.removeAt(index);
                                        editableRatings.remove(course.id);
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Quick Rating Row
                            Row(
                              children: [
                                _buildRateChip('أحتاج مساعدة', 1, rating == 1, Colors.orange.shade700, () {
                                  setModalState(() => editableRatings[course.id] = 1);
                                }),
                                const SizedBox(width: 6),
                                _buildRateChip('متوسط', 2, rating == 2, AppColors.primary, () {
                                  setModalState(() => editableRatings[course.id] = 2);
                                }),
                                const SizedBox(width: 6),
                                _buildRateChip('مستعد للشرح', 3, rating == 3, AppColors.deepSage, () {
                                  setModalState(() => editableRatings[course.id] = 3);
                                }),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setModalState(() => isSaving = true);

                            // 1. تحديث الخطة فوراً في الذاكرة الحية
                            ref.read(plannerProvider.notifier).updateCoursesAndRegeneratePlan(
                              editableCourses,
                              editableRatings,
                            );

                            // 2. الحفظ في فايربيس بشكل آمن
                            try {
                              await ref.read(authServiceProvider).updateUserProfile(
                                selectedCourses: editableCourses.map((c) => c.id).toList(),
                                coursesData: editableCourses.map((c) => c.toMap()).toList(),
                                courseRatings: editableRatings,
                              );
                            } catch (e) {
                              debugPrint('Manage courses firestore update warning: $e');
                            }

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم حفظ التعديلات وتحديث جدول المذاكرة بنجاح ✅'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          },
                    icon: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                    label: Text(
                      isSaving ? 'جارٍ حفظ التعديلات...' : 'حفظ التعديلات في حسابي',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHourChoice({
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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryContainer.withValues(alpha: 0.6) : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: selected ? AppColors.primary : AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 9, color: selected ? AppColors.primary : AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRateChip(String label, int score, bool selected, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? color : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
