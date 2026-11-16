// مطور 3
// فيجما: اليوم - ذاكر وعلّم

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../auth/data/auth_service.dart';
import '../../timebank/data/timebank_repository.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    final userId = user?.uid ?? '';

    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final userDoc = userProfileAsync.value?.data();
    final userName = (userDoc?['name'] as String?)?.isNotEmpty == true
        ? (userDoc!['name'] as String)
        : (user?.displayName?.isNotEmpty == true
            ? user!.displayName!
            : (user?.email?.split('@').first ?? 'طالب زميل'));

    final plannerState = ref.watch(plannerProvider);

    final timeCoins = ref.watch(userTimeCoinsProvider);

    const dayNames = {
      DateTime.saturday: 'السبت',
      DateTime.sunday: 'الأحد',
      DateTime.monday: 'الاثنين',
      DateTime.tuesday: 'الثلاثاء',
      DateTime.wednesday: 'الأربعاء',
      DateTime.thursday: 'الخميس',
      DateTime.friday: 'الجمعة',
    };
    const monthNames = {
      1: 'يناير',
      2: 'فبراير',
      3: 'مارس',
      4: 'أبريل',
      5: 'مايو',
      6: 'يونيو',
      7: 'يوليو',
      8: 'أغسطس',
      9: 'سبتمبر',
      10: 'أكتوبر',
      11: 'نوفمبر',
      12: 'ديسمبر',
    };
    final now = DateTime.now();
    final todayArabic = dayNames[now.weekday] ?? 'السبت';
    final monthArabic = monthNames[now.month] ?? '';
    final formattedTodayDate = 'اليوم • $todayArabic، ${now.day} $monthArabic';
    final todayBlocks = plannerState.studyBlocks.where((b) => b.day == todayArabic).toList();
    final hour = now.hour;
    final greeting = (hour >= 4 && hour < 12) ? 'صباح الخير' : 'مساء الخير';

    final learnerSessions = ref.watch(learnerSessionsStreamProvider(userId)).value ?? [];
    final teacherSessions = ref.watch(teacherSessionsStreamProvider(userId)).value ?? [];
    final allSessions = [...learnerSessions, ...teacherSessions];
    final confirmedSession = allSessions.isNotEmpty
        ? allSessions.firstWhere((s) => s.escrowStatus == 'held', orElse: () => allSessions.first)
        : null;

    final progressPct = plannerState.progressPercentage;
    final progressInt = (progressPct * 100).round();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Greeting & Time Coin Chip
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.hairline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Time Coin Chip
                    GestureDetector(
                      onTap: () => context.push('/wallet'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.pointsAmber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.pointsAmber.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.monetization_on_rounded,
                              size: 18,
                              color: AppColors.pointsAmber,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$timeCoins',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFFFD54F)
                                    : const Color(0xFF664700),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'نقاط وقت',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFFFD54F)
                                    : const Color(0xFF664700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),
                    // Greeting & Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$greeting يا $userName 👋',
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formattedTodayDate,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textTertiary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Section: Time Bank Peer Exchange Card (جلسة الأقران المحجوزة)
              if (confirmedSession != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => context.push('/my-sessions'),
                      child: const Text(
                        'عرض كل الجلسات',
                        style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      'جلسة تبادل قادمة 🤝',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    if (confirmedSession.teacherId == userId) {
                      context.push('/session-teacher', extra: confirmedSession);
                    } else {
                      context.push('/session-learner', extra: confirmedSession);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(18),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.sage.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'مؤكدة ✓',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.deepSage),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          confirmedSession.teacherId == userId
                                              ? 'أنت تشرح لـ ${confirmedSession.learnerName} ${confirmedSession.courseName}'
                                              : '${confirmedSession.teacherName} يشرح لك ${confirmedSession.courseName}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          confirmedSession.topic,
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  CircleAvatar(
                                    backgroundColor: AppColors.primaryContainer,
                                    radius: 18,
                                    child: Text(
                                      confirmedSession.teacherId == userId
                                          ? (confirmedSession.learnerName.trim().isNotEmpty
                                              ? confirmedSession.learnerName.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('.')
                                              : 'ز.م')
                                          : confirmedSession.teacherInitials,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppColors.hairline),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: confirmedSession.teacherId == userId
                                    ? AppColors.pointsAmber.withValues(alpha: 0.15)
                                    : AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                confirmedSession.teacherId == userId
                                    ? '+${confirmedSession.costCoins} عملة وقت (مكافأة)'
                                    : '-${confirmedSession.costCoins} عملة وقت (في الضمان)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: confirmedSession.teacherId == userId ? const Color(0xFF664700) : AppColors.error,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '${confirmedSession.day} • ${confirmedSession.time} (${confirmedSession.durationMinutes} دقيقة)',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textTertiary),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // 4. Section: Today's Timeline (جدول اليوم)
              Builder(
                builder: (context) {
                  final todayLectures = plannerState.lectureSchedule.where((l) => l.day == todayArabic).toList();
                  final totalTodayItems = todayLectures.length + todayBlocks.length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => context.push('/schedule-setup'),
                            child: const Text(
                              '+ إضافة / تعديل المحاضرات',
                              style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            'جدول اليوم ($totalTodayItems عناصر)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (totalTodayItems == 0)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: todayArabic == 'الجمعة'
                              ? Column(
                                  children: [
                                    const Text('🌴', style: TextStyle(fontSize: 44)),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'عطلة نهاية الأسبوع • يوم الجمعة المبارك',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'لا توجد جلسات مذاكرة أو محاضرات مجدولة اليوم. استمتع بيومك وجدد طاقتك قبل بداية الأسبوع الجديد!',
                                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: () => context.push('/plan'),
                                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                                      label: const Text('استعراض خطة الأسبوع'),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 40, color: AppColors.textSecondary),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'لا توجد محاضرات أو مذاكرة مجدولة اليوم',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'أضف مواعيد محاضراتك وموادك وسيقوم التطبيق بحساب أوقات فراغك وتوليد خطة مذاكرة ذكية لك تلقائياً.',
                                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 14),
                                    ElevatedButton.icon(
                                      onPressed: () => context.push('/schedule-setup'),
                                      icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                                      label: const Text('إعداد جدول المحاضرات الآن', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ],
                                ),
                        ),

                      // محاضرات اليوم المجدولة يدوياً
                      ...todayLectures.map((lec) {
                        return _buildTimelineItem(
                          context: context,
                          title: lec.courseName,
                          category: 'محاضرة رسمية',
                          room: lec.room,
                          time: '${lec.startTime} – ${lec.endTime}',
                          ribbonColor: lec.color,
                          statusText: 'محاضرة',
                          isDone: true,
                          onTap: () => context.push('/schedule-setup'),
                        );
                      }),

                      // كتل المذاكرة المتولدة تلقائياً بالخوارزمية الذكية حول المحاضرات
                      ...todayBlocks.map((block) {
                        return _buildTimelineItem(
                          context: context,
                          title: block.courseName,
                          category: block.topic,
                          room: block.room,
                          time: '${block.startTime} – ${block.endTime}',
                          ribbonColor: block.isCompleted ? AppColors.success : block.ribbonColor,
                          statusText: block.isCompleted ? 'تمت' : 'لم تتم',
                          isDone: block.isCompleted,
                          canToggle: true,
                          onToggleDone: () {
                            final wasCompleted = block.isCompleted;
                            ref.read(plannerProvider.notifier).toggleBlockCompleted(block.id);

                            final uid = ref.read(authServiceProvider).currentUser?.uid;

                            if (!wasCompleted) {
                              ref.read(userTimeCoinsProvider.notifier).addCoins(1);
                              if (uid != null && uid.isNotEmpty) {
                                ref.read(timeBankRepositoryProvider).awardStudyPoint(
                                  userId: uid,
                                  title: 'مكافأة إتمام مذاكرة: ${block.courseName}',
                                  blockId: block.id,
                                  points: 1,
                                );
                              }
                            } else {
                              ref.read(userTimeCoinsProvider.notifier).deductCoins(1);
                              if (uid != null && uid.isNotEmpty) {
                                ref.read(timeBankRepositoryProvider).revertStudyPoint(
                                  userId: uid,
                                  blockId: block.id,
                                  points: 1,
                                );
                              }
                            }

                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: !wasCompleted ? AppColors.success : AppColors.primary,
                                duration: const Duration(seconds: 2),
                                content: Text(
                                  !wasCompleted
                                      ? 'عاش! تم تسجيل مذاكرة "${block.courseName}" وحصلت على +1 نقطة وقت 🪙🎉'
                                      : 'تم إلغاء تحديد "${block.courseName}"',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          },
                          onTap: () => context.push('/study-block-details', extra: block),
                        );
                      }),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // 5. Progress Card: Weekly Goal Ring
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 54,
                          height: 54,
                          child: CircularProgressIndicator(
                            value: progressPct,
                            strokeWidth: 6,
                            backgroundColor: AppColors.surfaceAlt,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                        Text(
                          '$progressInt%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'معدل إنجاز الأسبوع',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'أنجزت ${plannerState.completedBlocksCount} من ${plannerState.totalWeeklyTarget} جلسات هذا الأسبوع',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'متبقي ${plannerState.totalWeeklyTarget - plannerState.completedBlocksCount} جلسات لتحقيق الهدف',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
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

  Widget _buildTimelineItem({
    required BuildContext context,
    required String title,
    required String category,
    required String room,
    required String time,
    required Color ribbonColor,
    required String statusText,
    required bool isDone,
    required VoidCallback onTap,
    VoidCallback? onToggleDone,
    bool canToggle = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 5,
                color: ribbonColor,
              ),
              Expanded(
                child: ListTile(
                  onTap: onTap,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (canToggle)
                        InkWell(
                          onTap: onToggleDone,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDone
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDone
                                    ? AppColors.success.withValues(alpha: 0.5)
                                    : AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  size: 13,
                                  color: isDone ? AppColors.success : AppColors.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isDone ? 'تم' : 'لم تتم',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDone ? AppColors.success : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDone ? AppColors.sage.withValues(alpha: 0.2) : AppColors.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDone ? AppColors.deepSage : AppColors.primary,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          time,
                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$category • $room',
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
      ),
    );
  }
}

