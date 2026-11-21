// مطور 2
// فيجما: حسابي - ذاكر وعلّم

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_tokens.dart';
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
    final tokens = context.tokens;
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
    final rawUsername = userDoc?['username'] as String?;
    final userHandle = (rawUsername != null && rawUsername.trim().isNotEmpty)
        ? '@${rawUsername.trim().replaceAll('@', '')}'
        : (userEmail.contains('@')
            ? '@${userEmail.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').toLowerCase()}'
            : '@zameel');
    final userBio = (userDoc?['bio'] as String?)?.trim() ?? '';

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
    final teacherRating = ratingCount > 0 ? (ratingSum / ratingCount) : 0.0;
    final hasRating = ratingCount > 0;
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
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.surface,
        elevation: 0,
        title: Text(
          'الملف الشخصي',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tokens.textHigh),
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
                  color: tokens.surface,
                  borderRadius: AppRadii.sheetRadius,
                  border: Border.all(color: tokens.border),
                ),
                child: Column(
                  children: [
                    // Avatar with Edit Button
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: tokens.brandContainer,
                          child: Text(
                            userName.isNotEmpty ? userName.substring(0, 1) : 'أ',
                            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: tokens.brand),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () => _showEditProfileModal(context, userDoc),
                            borderRadius: AppRadii.controlRadius,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: tokens.brand,
                                shape: BoxShape.circle,
                                border: Border.all(color: tokens.surface, width: 2),
                              ),
                              child: Icon(Icons.edit_rounded, size: 13, color: tokens.onBrand),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userName,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tokens.textHigh),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userHandle,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.brand),
                    ),
                    const SizedBox(height: 6),
                    // Teacher Rating Badge (0.0 / جديد if unrated)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasRating
                            ? tokens.warningContainer
                            : tokens.surfaceAlt,
                        borderRadius: AppRadii.cardRadius,
                        border: Border.all(
                          color: hasRating
                              ? tokens.warning.withValues(alpha: 0.4)
                              : tokens.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: hasRating ? tokens.warning : tokens.textLow,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasRating
                                ? 'تقييم كمعلم: ${teacherRating.toStringAsFixed(1)} ($ratingCount تقييم)'
                                : 'جديد (بدون تقييم)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: hasRating ? tokens.warning : tokens.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Bio text (or prompt to add bio)
                    InkWell(
                      onTap: () => _showEditProfileModal(context, userDoc),
                      borderRadius: AppRadii.controlRadius,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Text(
                          userBio.isNotEmpty ? '"$userBio"' : '+ أضف نبذة تعريفية عنك (Bio)...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: userBio.isNotEmpty ? FontStyle.italic : FontStyle.normal,
                            color: userBio.isNotEmpty ? tokens.textMedium : tokens.brand,
                            fontWeight: userBio.isNotEmpty ? FontWeight.normal : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: tokens.surfaceAlt,
                        borderRadius: AppRadii.cardRadius,
                      ),
                      child: Text(
                        '$faculty • $year • $term • $department',
                        style: TextStyle(fontSize: 11, color: tokens.textMedium, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Action Buttons: Edit Profile & Academic Setup
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showEditProfileModal(context, userDoc),
                          icon: Icon(Icons.person_outline_rounded, size: 14, color: tokens.brand),
                          label: Text('تعديل الملف الشخصي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.brand)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: tokens.brand.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/academic-setup?edit=true'),
                          icon: Icon(Icons.school_outlined, size: 14, color: tokens.brand),
                          label: Text('البيانات الأكاديمية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.brand)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: tokens.brand.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Academic Badges & Stats
              Row(
                children: [
                  Expanded(
                    child: _buildBadgeCard('رصيد الوقت', '$availableCoins عملة', Icons.toll_rounded, tokens.coin, tokens),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBadgeCard('ساعات المذاكرة', '$studyHours ساعة', Icons.timer_outlined, tokens.brand, tokens),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBadgeCard('جلسات مكتملة', '$completedSessions جلسة', Icons.check_circle_outline, tokens.success, tokens),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ==========================================
              // كارت محفظة الوقت
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: tokens.border),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: AppRadii.cardRadius,
                    onTap: () => context.push('/wallet'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.toll_rounded, color: tokens.coin, size: 26),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'محفظة عملات الوقت',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textHigh),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'رصيدك المتاح: $availableCoins عملة • الإجمالي: $totalCoins عملة',
                                  style: TextStyle(fontSize: 12, color: tokens.textMedium),
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
                                  color: tokens.coin.withValues(alpha: 0.15),
                                  borderRadius: AppRadii.fullRadius,
                                ),
                                child: Text(
                                  '$availableCoins عملة',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.coin,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_back_ios_rounded, size: 14, color: tokens.textMedium),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ==========================================
              // كارت موادي الدراسية
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: tokens.border),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: AppRadii.cardRadius,
                    onTap: () => _showCoursesBottomSheet(context, userCourses, userRatings),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.menu_book_outlined, color: tokens.brand, size: 26),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'المواد الدراسية (${userCourses.length})',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textHigh),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'المقررات المسجلة للفرقة والترم الحالي • اضغط للإدارة والتعديل',
                                  style: TextStyle(fontSize: 12, color: tokens.textMedium),
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
                                  color: tokens.brandContainer.withValues(alpha: 0.5),
                                  borderRadius: AppRadii.fullRadius,
                                ),
                                child: Text(
                                  '${userCourses.length} مواد',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.brand,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_back_ios_rounded, size: 14, color: tokens.textMedium),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // جدول المحاضرات الأسبوعية
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => context.push('/schedule-setup'),
                    icon: Icon(Icons.tune_rounded, size: 16, color: tokens.brand),
                    label: Text('إعداد وتعديل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tokens.brand)),
                  ),
                  Text(
                    'جدول المحاضرات (${plannerLectures.length})',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tokens.textHigh),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: tokens.border),
                ),
                child: plannerLectures.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () => context.push('/schedule-setup'),
                            icon: Icon(Icons.add_circle_outline_rounded, color: tokens.brand),
                            label: Text('أضف جدول محاضراتك لتوليد خطة المذاكرة الذكية', style: TextStyle(color: tokens.brand, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (int i = 0; i < plannerLectures.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: tokens.border),
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
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textHigh),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${plannerLectures[i].day} • ${plannerLectures[i].startTime} – ${plannerLectures[i].endTime} • ${plannerLectures[i].room}',
                                          style: TextStyle(fontSize: 11, color: tokens.textMedium),
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
                'إعدادات التطبيق',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tokens.textHigh),
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: tokens.border),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text('الوضع الداكن (Dark Theme)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textHigh)),
                      subtitle: Text('تبديل مظهر الشاشات للألوان الداكنة وحفظ التفضيل', style: TextStyle(fontSize: 12, color: tokens.textMedium)),
                      secondary: Icon(Icons.dark_mode_outlined, color: tokens.brand),
                      value: isDark,
                      activeTrackColor: tokens.brand,
                      onChanged: (val) {
                        ref.read(themeModeProvider.notifier).toggleTheme(val);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(val ? 'تم تفعيل الوضع الداكن بنجاح.' : 'تم تفعيل الوضع الفاتح بنجاح.'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: val ? tokens.surfaceAlt : tokens.brand,
                          ),
                        );
                      },
                    ),
                    Divider(height: 1, color: tokens.border),
                    SwitchListTile(
                      title: Text('الإشعارات والتنبيهات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textHigh)),
                      subtitle: Text('تنبيهات قبل بدء مواعيد المذاكرة والجلسات بـ 15 دقيقة', style: TextStyle(fontSize: 12, color: tokens.textMedium)),
                      secondary: Icon(Icons.notifications_none_rounded, color: tokens.brand),
                      value: _notifications,
                      activeTrackColor: tokens.brand,
                      onChanged: (val) => setState(() => _notifications = val),
                    ),
                    Divider(height: 1, color: tokens.border),
                    ListTile(
                      leading: Icon(Icons.help_outline_rounded, color: tokens.brand),
                      title: Text('المساعدة والدعم', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textHigh)),
                      subtitle: Text('الأسئلة الشائعة والتواصل مع فريق زميل', style: TextStyle(fontSize: 12, color: tokens.textMedium)),
                      trailing: Icon(Icons.arrow_back_ios_rounded, size: 14, color: tokens.textMedium),
                      onTap: () => _showSupportDialog(context),
                    ),
                    Divider(height: 1, color: tokens.border),
                    ListTile(
                      leading: Icon(Icons.logout_rounded, color: tokens.danger),
                      title: Text(
                        'تسجيل الخروج',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.danger),
                      ),
                      subtitle: Text('إنهاء الجلسة الحالية من هذا الجهاز', style: TextStyle(fontSize: 12, color: tokens.textMedium)),
                      trailing: Icon(Icons.arrow_back_ios_rounded, size: 14, color: tokens.danger),
                      onTap: () => _confirmSignOut(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    final tokens = context.tokens;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.sheetRadius,
          side: BorderSide(color: tokens.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tokens.brand.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.support_agent_rounded, color: tokens.brand, size: 22),
            ),
            const SizedBox(width: 10),
            Text(
              'المساعدة والدعم الفني',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: tokens.textHigh,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'فريق تطبيق زميل هنا لمساعدتك! إذا واجهت أي استفسار، مشكلة تقنية، أو رغبت في مشاركة اقتراحاتك لتطوير التطبيق، يمكنك التواصل معنا مباشرة عبر البريد الإلكتروني:',
              style: TextStyle(fontSize: 13, height: 1.4, color: tokens.textMedium),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: tokens.surfaceAlt,
                borderRadius: AppRadii.controlRadius,
                border: Border.all(color: tokens.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.email_outlined, color: tokens.brand, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      AppConstants.supportEmail,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: tokens.textHigh,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy_rounded, size: 18),
                    tooltip: 'نسخ الإيميل',
                    color: tokens.brand,
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: AppConstants.supportEmail));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم نسخ البريد الإلكتروني بنجاح.'),
                          backgroundColor: tokens.success,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('إغلاق', style: TextStyle(color: tokens.textMedium)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: tokens.brand,
              foregroundColor: tokens.onBrand,
              shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
            ),
            onPressed: () async {
              final uri = Uri.parse('mailto:${AppConstants.supportEmail}?subject=${Uri.encodeComponent("استفسار ودعم - تطبيق زميل")}');
              try {
                final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (!launched && context.mounted) {
                  Clipboard.setData(const ClipboardData(text: AppConstants.supportEmail));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم نسخ البريد الإلكتروني إلى الحافظة.'),
                      backgroundColor: tokens.brand,
                    ),
                  );
                }
              } catch (_) {
                Clipboard.setData(const ClipboardData(text: AppConstants.supportEmail));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم نسخ البريد الإلكتروني إلى الحافظة.'),
                      backgroundColor: tokens.brand,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('مراسلة الآن', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(String label, String value, IconData icon, Color color, AppTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: AppRadii.controlRadius,
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: tokens.textMedium)),
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

  Widget _buildCourseRow(CourseSeed course, int rating, AppTokens tokens) {
    String ratingLabel;
    Color ratingColor;
    switch (rating) {
      case 1:
        ratingLabel = 'أحتاج مساعدة';
        ratingColor = tokens.warning;
        break;
      case 3:
        ratingLabel = 'مستعد للشرح';
        ratingColor = tokens.success;
        break;
      case 2:
      default:
        ratingLabel = 'متوسط';
        ratingColor = tokens.brand;
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textHigh),
                ),
                const SizedBox(height: 2),
                Text(
                  course.code,
                  style: TextStyle(fontSize: 11, color: tokens.textMedium),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: course.creditHours >= 3 ? tokens.warningContainer : tokens.surfaceAlt,
              borderRadius: AppRadii.controlRadius,
            ),
            child: Text(
              '${course.creditHours} ساعات',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: course.creditHours >= 3 ? tokens.warning : tokens.textMedium,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ratingColor.withValues(alpha: 0.15),
              borderRadius: AppRadii.controlRadius,
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
    final tokens = context.tokens;
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
                        'إضافة مادة جديدة',
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
                    'ستتم إضافتها إلى خطة مذاكرتك وبنك الوقت مع زملائك',
                    style: TextStyle(fontSize: 12, color: tokens.textMedium),
                  ),
                  const SizedBox(height: 20),

                  // Course Name
                  Text('اسم المادة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textHigh)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: tokens.textHigh),
                    decoration: InputDecoration(
                      hintText: 'مثال: الذكاء الاصطناعي (AI)',
                      hintStyle: TextStyle(color: tokens.textMedium),
                      filled: true,
                      fillColor: tokens.surfaceAlt,
                      border: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide.none),
                      prefixIcon: Icon(Icons.book_outlined, color: tokens.brand),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Course Code
                  Text('كود المادة (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textHigh)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: codeController,
                    style: TextStyle(color: tokens.textHigh),
                    decoration: InputDecoration(
                      hintText: 'مثال: AI301',
                      hintStyle: TextStyle(color: tokens.textMedium),
                      filled: true,
                      fillColor: tokens.surfaceAlt,
                      border: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide.none),
                      prefixIcon: Icon(Icons.tag_rounded, color: tokens.brand),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Credit Hours
                  Text('الساعات المعتمدة للمادة (الأهمية)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textHigh)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildHourChoice(
                        hours: 2,
                        label: 'ساعتان (2h)',
                        subtitle: 'وزن أساسي',
                        selected: selectedCreditHours == 2,
                        tokens: tokens,
                        onTap: () => setModalState(() => selectedCreditHours = 2),
                      ),
                      const SizedBox(width: 8),
                      _buildHourChoice(
                        hours: 3,
                        label: '3 ساعات (3h)',
                        subtitle: 'أولوية عالية',
                        selected: selectedCreditHours == 3,
                        tokens: tokens,
                        onTap: () => setModalState(() => selectedCreditHours = 3),
                      ),
                      const SizedBox(width: 8),
                      _buildHourChoice(
                        hours: 4,
                        label: '4 ساعات (4h)',
                        subtitle: 'أولوية قصوى',
                        selected: selectedCreditHours == 4,
                        tokens: tokens,
                        onTap: () => setModalState(() => selectedCreditHours = 4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Rating in this course
                  Text('تقييم مستواك في المادة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textHigh)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildRateChip('أحتاج مساعدة', 1, selectedRating == 1, tokens.warning, tokens, () {
                        setModalState(() => selectedRating = 1);
                      }),
                      const SizedBox(width: 8),
                      _buildRateChip('متوسط', 2, selectedRating == 2, tokens.brand, tokens, () {
                        setModalState(() => selectedRating = 2);
                      }),
                      const SizedBox(width: 8),
                      _buildRateChip('مستعد للشرح', 3, selectedRating == 3, tokens.success, tokens, () {
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
                          color: tokens.courseTeal,
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
                              content: Text('تمت إضافة مادة "$name" بنجاح.'),
                              backgroundColor: tokens.success,
                            ),
                          );
                        }
                      },
                      icon: isSaving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: tokens.onBrand),
                            )
                          : Icon(Icons.add_task_rounded, color: tokens.onBrand),
                      label: Text(
                        isSaving ? 'جارٍ الحفظ...' : 'إضافة المادة وحفظها',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tokens.onBrand),
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
    final tokens = context.tokens;
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
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: AppRadii.sheetTopRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تعديل المواد المقررة والتقييمات',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tokens.textHigh),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: tokens.textMedium),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'يمكنك تعديل تقييمك وساعات كل مادة أو حذفها، وسيتم تحديث جدول مذاكرتك وبنك الوقت فوراً',
                  style: TextStyle(fontSize: 12, color: tokens.textMedium),
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
                          color: tokens.surfaceAlt.withValues(alpha: 0.5),
                          borderRadius: AppRadii.controlRadius,
                          border: Border.all(color: tokens.border),
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
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textHigh),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: course.creditHours >= 3 ? tokens.warningContainer : tokens.surface,
                                    borderRadius: AppRadii.controlRadius,
                                  ),
                                  child: Text(
                                    '${course.creditHours} ساعات',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: course.creditHours >= 3 ? tokens.warning : tokens.textMedium,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                if (editableCourses.length > 1)
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, color: tokens.danger, size: 20),
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
                                _buildRateChip('أحتاج مساعدة', 1, rating == 1, tokens.warning, tokens, () {
                                  setModalState(() => editableRatings[course.id] = 1);
                                }),
                                const SizedBox(width: 6),
                                _buildRateChip('متوسط', 2, rating == 2, tokens.brand, tokens, () {
                                  setModalState(() => editableRatings[course.id] = 2);
                                }),
                                const SizedBox(width: 6),
                                _buildRateChip('مستعد للشرح', 3, rating == 3, tokens.success, tokens, () {
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
                                SnackBar(
                                  content: Text('تم حفظ التعديلات وتحديث الخطة بنجاح.'),
                                  backgroundColor: tokens.success,
                                ),
                              );
                            }
                          },
                    icon: isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: tokens.onBrand),
                          )
                        : Icon(Icons.check_circle_outline_rounded, color: tokens.onBrand),
                    label: Text(
                      isSaving ? 'جارٍ حفظ التعديلات...' : 'حفظ التعديلات في حسابي',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tokens.onBrand),
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
    required AppTokens tokens,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? tokens.brandContainer.withValues(alpha: 0.6) : tokens.surfaceAlt,
            borderRadius: AppRadii.controlRadius,
            border: Border.all(
              color: selected ? tokens.brand : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: selected ? tokens.brand : tokens.textHigh),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 9, color: selected ? tokens.brand : tokens.textMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRateChip(String label, int score, bool selected, Color color, AppTokens tokens, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : tokens.surfaceAlt,
            borderRadius: AppRadii.controlRadius,
            border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? color : tokens.textMedium,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final tokens = context.tokens;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        title: Text('تسجيل الخروج', style: TextStyle(color: tokens.textHigh)),
        content: Text('هل أنت متأكد من رغبتك في تسجيل الخروج من تطبيق زميل؟', style: TextStyle(color: tokens.textMedium)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: tokens.textMedium)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: tokens.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، تسجيل الخروج'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ref.read(plannerProvider.notifier).switchUser(null);
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) {
        context.go('/welcome');
      }
    }
  }

  void _showCoursesBottomSheet(
    BuildContext context,
    List<CourseSeed> currentCourses,
    Map<String, int> currentRatings,
  ) {
    final tokens = context.tokens;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: AppRadii.sheetTopRadius,
              border: Border.all(color: tokens.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.border,
                    borderRadius: AppRadii.controlRadius,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.menu_book_outlined, color: tokens.brand, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'المواد الدراسية (${currentCourses.length})',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textHigh),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              _showAddCourseModal(context, currentCourses, currentRatings);
                            },
                            borderRadius: AppRadii.controlRadius,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: tokens.brandContainer.withValues(alpha: 0.5),
                                borderRadius: AppRadii.controlRadius,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.add_circle_outline_rounded, size: 14, color: tokens.brand),
                                  const SizedBox(width: 4),
                                  Text(
                                    'إضافة',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.brand),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              _showManageCoursesModal(context, currentCourses, currentRatings);
                            },
                            borderRadius: AppRadii.controlRadius,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: tokens.surfaceAlt,
                                borderRadius: AppRadii.controlRadius,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.tune_rounded, size: 14, color: tokens.textMedium),
                                  const SizedBox(width: 4),
                                  Text(
                                    'تعديل',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textMedium),
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
                Divider(height: 1, color: tokens.border),
                Flexible(
                  child: currentCourses.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text('لا توجد مواد مسجلة حالياً', style: TextStyle(color: tokens.textMedium)),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: currentCourses.length,
                          separatorBuilder: (_, _) => Divider(height: 1, color: tokens.border),
                          itemBuilder: (context, index) {
                            final course = currentCourses[index];
                            final rating = currentRatings[course.id] ?? 2;
                            return _buildCourseRow(
                              course,
                              rating,
                              tokens,
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditProfileModal(BuildContext context, Map<String, dynamic>? userDoc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProfileSheet(userDoc: userDoc),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? userDoc;

  const _EditProfileSheet({required this.userDoc});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;

  bool _isSaving = false;
  String? _errorMessage;

  bool _isNameLocked = false;
  int _nameRemainingDays = 0;

  bool _isUsernameLocked = false;
  int _usernameRemainingDays = 0;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authServiceProvider).currentUser;
    final doc = widget.userDoc;

    final initialName = (doc?['name'] as String?)?.isNotEmpty == true
        ? (doc!['name'] as String)
        : (user?.displayName ?? '');

    final initialUsername = (doc?['username'] as String?)?.trim().replaceAll('@', '') ??
        (user?.email != null && user!.email!.contains('@')
            ? user.email!.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').toLowerCase()
            : '');

    final initialBio = (doc?['bio'] as String?) ?? '';

    _nameController = TextEditingController(text: initialName);
    _usernameController = TextEditingController(text: initialUsername);
    _bioController = TextEditingController(text: initialBio);

    _checkCooldowns();
  }

  void _checkCooldowns() {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      try {
        return (val as dynamic).toDate();
      } catch (_) {
        return null;
      }
    }

    final doc = widget.userDoc;
    final now = DateTime.now();

    final lastNameChange = parseDate(doc?['lastDisplayNameChangedAt']);
    if (lastNameChange != null) {
      final diff = now.difference(lastNameChange).inDays;
      if (diff < 7) {
        _isNameLocked = true;
        _nameRemainingDays = 7 - diff;
      }
    }

    final lastUsernameChange = parseDate(doc?['lastUsernameChangedAt']);
    if (lastUsernameChange != null) {
      final diff = now.difference(lastUsernameChange).inDays;
      if (diff < 14) {
        _isUsernameLocked = true;
        _usernameRemainingDays = 14 - diff;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tokens = context.tokens;
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim().replaceAll('@', '');
    final bio = _bioController.text.trim();

    if (!_isNameLocked && (name.length < 3 || name.length > 35)) {
      setState(() => _errorMessage = 'الاسم يجب أن يتراوح بين 3 و 35 حرفاً');
      return;
    }

    if (!_isUsernameLocked) {
      final regex = RegExp(r'^[a-z0-9_]{3,20}$');
      if (!regex.hasMatch(username)) {
        setState(() => _errorMessage = 'اسم المستخدم يجب أن يتكون من 3 إلى 20 حرفاً (أحرف إنجليزية صغيرة، أرقام، و _ فقط)');
        return;
      }
    }

    if (bio.length > 120) {
      setState(() => _errorMessage = 'النبذة التعريفية يجب ألا تتجاوز 120 حرفاً');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).updateProfileDetails(
        newName: _isNameLocked ? null : name,
        newUsername: _isUsernameLocked ? null : username,
        newBio: bio,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث بيانات الملف الشخصي بنجاح.'),
            backgroundColor: tokens.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.border,
                  borderRadius: AppRadii.controlRadius,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تعديل الملف الشخصي',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tokens.textHigh),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: tokens.textMedium),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'يمكنك تحديث بياناتك الشخصية مع مراعاة فترات التهدئة وسياسات الأمان.',
              style: TextStyle(fontSize: 12, color: tokens.textMedium),
            ),
            const SizedBox(height: 18),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: tokens.dangerContainer,
                  borderRadius: AppRadii.controlRadius,
                  border: Border.all(color: tokens.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: tokens.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 12, color: tokens.danger, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Display Name
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الاسم الكامل', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textHigh)),
                if (_isNameLocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: tokens.warningContainer,
                      borderRadius: AppRadii.controlRadius,
                    ),
                    child: Text(
                      'متاح التغيير بعد $_nameRemainingDays يوم',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.warning),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              enabled: !_isNameLocked,
              style: TextStyle(color: _isNameLocked ? tokens.textMedium : tokens.textHigh),
              decoration: InputDecoration(
                hintText: 'أدخل اسمك الحقيقي',
                hintStyle: TextStyle(color: tokens.textMedium),
                filled: true,
                fillColor: _isNameLocked ? tokens.surfaceAlt.withValues(alpha: 0.5) : tokens.surfaceAlt,
                prefixIcon: Icon(Icons.badge_outlined, color: _isNameLocked ? tokens.textMedium : tokens.brand),
                border: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            // Username
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('اسم المستخدم (@handle)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textHigh)),
                if (_isUsernameLocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: tokens.warningContainer,
                      borderRadius: AppRadii.controlRadius,
                    ),
                    child: Text(
                      'متاح التغيير بعد $_usernameRemainingDays يوم',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.warning),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _usernameController,
              enabled: !_isUsernameLocked,
              style: TextStyle(color: _isUsernameLocked ? tokens.textMedium : tokens.textHigh),
              decoration: InputDecoration(
                hintText: 'e.g. ahmed_cs',
                hintStyle: TextStyle(color: tokens.textMedium),
                prefixText: '@ ',
                prefixStyle: TextStyle(color: tokens.brand, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: _isUsernameLocked ? tokens.surfaceAlt.withValues(alpha: 0.5) : tokens.surfaceAlt,
                prefixIcon: Icon(Icons.alternate_email_rounded, color: _isUsernameLocked ? tokens.textMedium : tokens.brand),
                border: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            // Bio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('النبذة التعريفية (Bio)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textHigh)),
                ListenableBuilder(
                  listenable: _bioController,
                  builder: (context, _) => Text(
                    '${_bioController.text.length} / 120',
                    style: TextStyle(
                      fontSize: 11,
                      color: _bioController.text.length > 120 ? tokens.danger : tokens.textMedium,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _bioController,
              maxLines: 3,
              maxLength: 120,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => const SizedBox.shrink(),
              style: TextStyle(color: tokens.textHigh),
              decoration: InputDecoration(
                hintText: 'اكتب نبذة قصيرة عن اهتماماتك الأكاديمية وطموحك...',
                hintStyle: TextStyle(color: tokens.textMedium),
                filled: true,
                fillColor: tokens.surfaceAlt,
                border: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // Save Button
            FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: tokens.brand,
                foregroundColor: tokens.onBrand,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
              ),
              child: _isSaving
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: tokens.onBrand),
                    )
                  : const Text(
                      'حفظ التغييرات',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}