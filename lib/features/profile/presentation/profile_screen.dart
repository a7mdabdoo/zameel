// مطور 2
// فيجما: حسابي - ذاكر وعلّم

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_service.dart';
import '../../../core/state/app_state.dart';
import '../../timebank/application/timebank_pure_logic.dart';
import '../../timebank/data/timebank_repository.dart';

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
    final scaffoldBgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final surfaceAltColor = isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt;
    final textPrimaryColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final hairlineColor = isDark ? AppColors.darkHairline : AppColors.hairline;
    final primaryContainerColor = isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

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
    final year = userDoc?['year'] as String? ??
        (userDoc?['academicYear'] != null ? CurriculumConstants.academicYearLabels[userDoc!['academicYear']] : null) ??
        AppConstants.academicYear;
    final term = userDoc?['term'] as String? ??
        (userDoc?['semester'] != null ? CurriculumConstants.semesterLabels[userDoc!['semester']] : null) ??
        'الترم الأول';
    final department = userDoc?['department'] as String? ?? 'عام (General)';
    final completedSessions = (userDoc?['completedSessions'] as num?)?.toInt() ?? 0;
    final ratingSum = (userDoc?['ratingSum'] as num?)?.toInt() ?? 0;
    final ratingCount = (userDoc?['ratingCount'] as num?)?.toInt() ?? 0;
    final teacherRating = ratingCount > 0 ? (ratingSum / ratingCount) : 5.0;
    final completedBlocks = (userDoc?['completedBlockIds'] as List<dynamic>?) ?? [];
    final studyHours = completedBlocks.isNotEmpty 
        ? completedBlocks.length 
        : ((userDoc?['studyHours'] as num?)?.toInt() ?? 0);

    // بيانات المحفظة ورصيد عملات الوقت الحي من Firestore
    final availableCoins = ref.watch(userTimeCoinsProvider);
    final learnerSessionsAsync = ref.watch(learnerSessionsStreamProvider(user?.uid ?? ''));
    final learnerSessions = learnerSessionsAsync.value ?? [];
    final heldCoins = TimeBankPureLogic.calculateHeldCoins(learnerSessions);
    final totalCoins = availableCoins + heldCoins;

    // استخراج المواد الدراسية وتقييمات الطالب من فايربيس
    final userCourses = _getUserCourses(userDoc);
    final userRatings = _getUserRatings(userDoc, userCourses);

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        title: Text(
          'الملف الشخصي 👤',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimaryColor),
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
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: hairlineColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: primaryContainerColor,
                      child: Text(
                        userName.isNotEmpty ? userName.substring(0, 1) : 'أ',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userName,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimaryColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userEmail,
                      style: TextStyle(fontSize: 13, color: textSecondaryColor),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: surfaceAltColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$faculty • $year • $term • $department',
                        style: TextStyle(fontSize: 11, color: textSecondaryColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => context.push('/academic-setup?edit=true'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_calendar_rounded, size: 14, color: primaryColor),
                            const SizedBox(width: 6),
                            Text(
                              'تعديل الفرقة الدراسية والترم ✏️',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
                            ),
                          ],
                        ),
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
                    child: _buildBadgeCard('جلسات مكتملة', '$completedSessions جلسة', Icons.check_circle_outline, AppColors.deepSage, isDark, surfaceColor, hairlineColor, textSecondaryColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBadgeCard('تقييم كمعلم', '${teacherRating.toStringAsFixed(1)} ★', Icons.star_outline_rounded, AppColors.pointsAmber, isDark, surfaceColor, hairlineColor, textSecondaryColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBadgeCard('ساعات المذاكرة', '$studyHours ساعة', Icons.timer_outlined, primaryColor, isDark, surfaceColor, hairlineColor, textSecondaryColor),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ==========================================
              // كارت محفظة الوقت (شبه تابة الوضع الليلي مباشرة قبل موادي الدراسية)
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: hairlineColor),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => context.push('/wallet'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, color: AppColors.pointsAmber, size: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'محفظة عملات الوقت 🪙',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimaryColor),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'رصيدك المتاح: $availableCoins عملة • الإجمالي: $totalCoins عملة',
                                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.pointsAmber.withValues(alpha: isDark ? 0.25 : 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$availableCoins عملة',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.pointsAmber,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_back_ios_rounded, size: 14, color: textSecondaryColor),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ==========================================
              // كارت موادي الدراسية (تحت محفظة الوقت مباشرة بنفس الستايل)
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: hairlineColor),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.menu_book_outlined, color: primaryColor, size: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'موادي الدراسية 📚 (${userCourses.length})',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimaryColor),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'المقررات المسجلة للفرقة والترم الحالي',
                                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => _showAddCourseModal(context, userCourses, userRatings, isDark),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.add_circle_outline_rounded, size: 15, color: primaryColor),
                                      const SizedBox(width: 3),
                                      Text(
                                        'إضافة',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _showManageCoursesModal(context, userCourses, userRatings, isDark),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.tune_rounded, size: 15, color: textSecondaryColor),
                                      const SizedBox(width: 3),
                                      Text(
                                        'تعديل',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondaryColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (userCourses.isNotEmpty) ...[
                      for (int i = 0; i < userCourses.length; i++) ...[
                        Divider(height: 1, color: hairlineColor),
                        _buildCourseRow(
                          userCourses[i],
                          userRatings[userCourses[i].id] ?? 2,
                          isDark,
                          textPrimaryColor,
                          textSecondaryColor,
                          surfaceAltColor,
                        ),
                      ],
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
                    icon: Icon(Icons.tune_rounded, size: 16, color: primaryColor),
                    label: Text('إعداد وتعديل 🗓️', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor)),
                  ),
                  Text(
                    'جدول محاضراتي 🗓️ (${plannerLectures.length})',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: hairlineColor),
                ),
                child: plannerLectures.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () => context.push('/schedule-setup'),
                            icon: Icon(Icons.add_circle_outline_rounded, color: primaryColor),
                            label: Text('أضف جدول محاضراتك لتوليد خطة المذاكرة الذكية', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (int i = 0; i < plannerLectures.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: hairlineColor),
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
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimaryColor),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${plannerLectures[i].day} • ${plannerLectures[i].startTime} – ${plannerLectures[i].endTime} • ${plannerLectures[i].room}',
                                          style: TextStyle(fontSize: 11, color: textSecondaryColor),
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
              Text(
                'إعدادات التطبيق ⚙️',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimaryColor),
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: hairlineColor),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text('الوضع الليلي (Dark Theme)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimaryColor)),
                      subtitle: Text('تبديل مظهر الشاشات للألوان الداكنة', style: TextStyle(fontSize: 12, color: textSecondaryColor)),
                      secondary: Icon(Icons.dark_mode_outlined, color: primaryColor),
                      value: isDark,
                      activeTrackColor: primaryColor,
                      onChanged: (val) {
                        ref.read(themeModeProvider.notifier).toggleTheme(val);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(val ? 'تم تفعيل الوضع الداكن بنجاح 🌙' : 'تم تفعيل الوضع الفاتح بنجاح ☀️')),
                        );
                      },
                    ),
                    Divider(height: 1, color: hairlineColor),
                    SwitchListTile(
                      title: Text('تنبيهات المذاكرة والجلسات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimaryColor)),
                      subtitle: Text('إشعارات قبل بدء المواعيد بـ 15 دقيقة', style: TextStyle(fontSize: 12, color: textSecondaryColor)),
                      secondary: Icon(Icons.notifications_none_rounded, color: primaryColor),
                      value: _notifications,
                      activeTrackColor: primaryColor,
                      onChanged: (val) => setState(() => _notifications = val),
                    ),
                    Divider(height: 1, color: hairlineColor),
                    ListTile(
                      leading: Icon(Icons.privacy_tip_outlined, color: textSecondaryColor),
                      title: Text('سياسة الخصوصية وبنك الساعات', style: TextStyle(fontSize: 14, color: textPrimaryColor)),
                      trailing: Icon(Icons.arrow_back_ios_rounded, size: 14, color: textSecondaryColor),
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Sign Out Button -> /welcome
              OutlinedButton.icon(
                onPressed: () async {
                  ref.read(plannerProvider.notifier).switchUser(null);
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

  Widget _buildBadgeCard(String label, String value, IconData icon, Color color, bool isDark, Color surfaceColor, Color hairlineColor, Color textSecondaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hairlineColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: textSecondaryColor)),
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

  Widget _buildCourseRow(CourseSeed course, int rating, bool isDark, Color textPrimaryColor, Color textSecondaryColor, Color surfaceAltColor) {
    String ratingLabel;
    Color ratingColor;
    switch (rating) {
      case 1:
        ratingLabel = 'أحتاج مساعدة';
        ratingColor = Colors.orange.shade700;
        break;
      case 3:
        ratingLabel = 'مستعد للشرح';
        ratingColor = isDark ? AppColors.darkPrimary : AppColors.deepSage;
        break;
      case 2:
      default:
        ratingLabel = 'متوسط';
        ratingColor = isDark ? AppColors.darkPrimary : AppColors.primary;
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimaryColor),
                ),
                const SizedBox(height: 2),
                Text(
                  course.code,
                  style: TextStyle(fontSize: 11, color: textSecondaryColor),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: course.creditHours >= 3 ? AppColors.pointsAmber.withValues(alpha: 0.15) : surfaceAltColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${course.creditHours} ساعات',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: course.creditHours >= 3 ? (isDark ? const Color(0xFFFFD54F) : const Color(0xFF664700)) : textSecondaryColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ratingColor.withValues(alpha: 0.15),
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
    bool isDark,
  ) {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    int selectedCreditHours = 3;
    int selectedRating = 2;
    bool isSaving = false;

    final modalSurface = isDark ? AppColors.darkSurface : Colors.white;
    final modalSurfaceAlt = isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt;
    final modalTextPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final modalTextSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final modalPrimary = isDark ? AppColors.darkPrimary : AppColors.primary;
    final modalPrimaryContainer = isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer;

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
            decoration: BoxDecoration(
              color: modalSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                        'إضافة مادة جديدة لحسابي ➕',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: modalTextPrimary),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: modalTextSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ستتم إضافتها إلى خطة مذاكرتك وبنك الوقت مع زملائك',
                    style: TextStyle(fontSize: 12, color: modalTextSecondary),
                  ),
                  const SizedBox(height: 20),

                  // Course Name
                  Text('اسم المادة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: modalTextPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: modalTextPrimary),
                    decoration: InputDecoration(
                      hintText: 'مثال: الذكاء الاصطناعي (AI)',
                      hintStyle: TextStyle(color: modalTextSecondary),
                      filled: true,
                      fillColor: modalSurfaceAlt,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: Icon(Icons.book_outlined, color: modalPrimary),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Course Code
                  Text('كود المادة (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: modalTextPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: codeController,
                    style: TextStyle(color: modalTextPrimary),
                    decoration: InputDecoration(
                      hintText: 'مثال: AI301',
                      hintStyle: TextStyle(color: modalTextSecondary),
                      filled: true,
                      fillColor: modalSurfaceAlt,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: Icon(Icons.tag_rounded, color: modalPrimary),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Credit Hours
                  Text('الساعات المعتمدة للمادة (الأهمية)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: modalTextPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildHourChoice(
                        hours: 2,
                        label: 'ساعتان (2h)',
                        subtitle: 'وزن أساسي',
                        selected: selectedCreditHours == 2,
                        isDark: isDark,
                        modalPrimary: modalPrimary,
                        modalPrimaryContainer: modalPrimaryContainer,
                        modalSurfaceAlt: modalSurfaceAlt,
                        modalTextPrimary: modalTextPrimary,
                        modalTextSecondary: modalTextSecondary,
                        onTap: () => setModalState(() => selectedCreditHours = 2),
                      ),
                      const SizedBox(width: 8),
                      _buildHourChoice(
                        hours: 3,
                        label: '3 ساعات (3h)',
                        subtitle: 'أولوية أعلى ⭐',
                        selected: selectedCreditHours == 3,
                        isDark: isDark,
                        modalPrimary: modalPrimary,
                        modalPrimaryContainer: modalPrimaryContainer,
                        modalSurfaceAlt: modalSurfaceAlt,
                        modalTextPrimary: modalTextPrimary,
                        modalTextSecondary: modalTextSecondary,
                        onTap: () => setModalState(() => selectedCreditHours = 3),
                      ),
                      const SizedBox(width: 8),
                      _buildHourChoice(
                        hours: 4,
                        label: '4 ساعات (4h)',
                        subtitle: 'أولوية قصوى 🔥',
                        selected: selectedCreditHours == 4,
                        isDark: isDark,
                        modalPrimary: modalPrimary,
                        modalPrimaryContainer: modalPrimaryContainer,
                        modalSurfaceAlt: modalSurfaceAlt,
                        modalTextPrimary: modalTextPrimary,
                        modalTextSecondary: modalTextSecondary,
                        onTap: () => setModalState(() => selectedCreditHours = 4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Rating in this course
                  Text('تقييم مستواك في المادة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: modalTextPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildRateChip('أحتاج مساعدة', 1, selectedRating == 1, Colors.orange.shade700, modalSurfaceAlt, modalTextSecondary, () {
                        setModalState(() => selectedRating = 1);
                      }),
                      const SizedBox(width: 8),
                      _buildRateChip('متوسط', 2, selectedRating == 2, modalPrimary, modalSurfaceAlt, modalTextSecondary, () {
                        setModalState(() => selectedRating = 2);
                      }),
                      const SizedBox(width: 8),
                      _buildRateChip('مستعد للشرح', 3, selectedRating == 3, isDark ? AppColors.darkPrimary : AppColors.deepSage, modalSurfaceAlt, modalTextSecondary, () {
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
                        backgroundColor: modalPrimary,
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
    bool isDark,
  ) {
    List<CourseSeed> editableCourses = List<CourseSeed>.from(currentCourses);
    Map<String, int> editableRatings = Map<String, int>.from(currentRatings);
    bool isSaving = false;

    final modalSurface = isDark ? AppColors.darkSurface : Colors.white;
    final modalSurfaceAlt = isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt;
    final modalTextPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final modalTextSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final modalHairline = isDark ? AppColors.darkHairline : AppColors.hairline;
    final modalPrimary = isDark ? AppColors.darkPrimary : AppColors.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 20),
            decoration: BoxDecoration(
              color: modalSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تعديل المواد المقررة والتقييمات ✏️',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: modalTextPrimary),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: modalTextSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'يمكنك تعديل تقييمك وساعات كل مادة أو حذفها، وسيتم تحديث جدول مذاكرتك وبنك الوقت فوراً',
                  style: TextStyle(fontSize: 12, color: modalTextSecondary),
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
                          color: modalSurfaceAlt.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: modalHairline),
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
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: modalTextPrimary),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: course.creditHours >= 3 ? AppColors.pointsAmber.withValues(alpha: 0.2) : modalSurface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${course.creditHours} ساعات',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: course.creditHours >= 3 ? (isDark ? const Color(0xFFFFD54F) : const Color(0xFF664700)) : modalTextSecondary,
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
                                _buildRateChip('أحتاج مساعدة', 1, rating == 1, Colors.orange.shade700, modalSurfaceAlt, modalTextSecondary, () {
                                  setModalState(() => editableRatings[course.id] = 1);
                                }),
                                const SizedBox(width: 6),
                                _buildRateChip('متوسط', 2, rating == 2, modalPrimary, modalSurfaceAlt, modalTextSecondary, () {
                                  setModalState(() => editableRatings[course.id] = 2);
                                }),
                                const SizedBox(width: 6),
                                _buildRateChip('مستعد للشرح', 3, rating == 3, isDark ? AppColors.darkPrimary : AppColors.deepSage, modalSurfaceAlt, modalTextSecondary, () {
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
                      backgroundColor: modalPrimary,
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
    required bool isDark,
    required Color modalPrimary,
    required Color modalPrimaryContainer,
    required Color modalSurfaceAlt,
    required Color modalTextPrimary,
    required Color modalTextSecondary,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? modalPrimaryContainer.withValues(alpha: 0.6) : modalSurfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? modalPrimary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: selected ? modalPrimary : modalTextPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 9, color: selected ? modalPrimary : modalTextSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRateChip(String label, int score, bool selected, Color color, Color modalSurfaceAlt, Color modalTextSecondary, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : modalSurfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? color : modalTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
