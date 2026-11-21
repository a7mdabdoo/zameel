// مطور 3
// فيجما: اليوم - ذاكر وعلّم

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/state/app_state.dart';
import '../../auth/data/auth_service.dart';
import '../../timebank/data/timebank_repository.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
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

    final nameParts = userName.trim().split(' ').where((s) => s.isNotEmpty).toList();
    final displayName = nameParts.length > 2 ? '${nameParts[0]} ${nameParts[1]}' : userName;

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

    final todayBlocksCount = todayBlocks.length;
    final todayCompletedCount = todayBlocks.where((b) => b.isCompleted).length;
    final todayRemainingCount = (todayBlocksCount - todayCompletedCount).clamp(0, todayBlocksCount);
    final double dailyProgressPct = todayBlocksCount > 0
        ? (todayCompletedCount / todayBlocksCount).clamp(0.0, 1.0)
        : 1.0;
    final int dailyProgressInt = (dailyProgressPct * 100).round();

    final streak = ref.watch(userStreakProvider);
    final savedCompleted = (userDoc?['completedBlockIds'] as List<dynamic>?)?.cast<String>() ?? [];
    final todayKey = 'daily_done_${now.year}_${now.month}_${now.day}';

    // فحص ذاتي: إذا كانت جميع مهام اليوم مكتملة بنسبة 100% ولم يسجل مفتاح اليوم في Firestore بعد، يتم تسجيله فوراً
    if (todayBlocksCount > 0 && todayRemainingCount == 0 && !savedCompleted.contains(todayKey) && userId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(timeBankRepositoryProvider).awardStudyPoint(
          userId: userId,
          title: 'مكافأة إتمام جميع مهام اليوم',
          blockId: todayKey,
          points: 1,
        );
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Greeting & Time Coin Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: tokens.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Right side (RTL): Greeting & Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting، $displayName',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: tokens.textHigh,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 12, color: tokens.brand),
                              const SizedBox(width: 5),
                              Text(
                                formattedTodayDate,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: tokens.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Left side (RTL): Chips (Streak & Coins)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Streak Chip
                        Tooltip(
                          message: streak > 0
                              ? 'الستريك اليومي: $streak'
                              : 'أتمم مهام اليوم لبدء التتابع اليومي',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: streak > 0
                                  ? tokens.warning.withValues(alpha: 0.15)
                                  : tokens.surfaceAlt,
                              borderRadius: AppRadii.cardRadius,
                              border: Border.all(
                                color: streak > 0
                                    ? tokens.warning.withValues(alpha: 0.4)
                                    : tokens.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_fire_department_rounded, size: 16, color: tokens.warning),
                                const SizedBox(width: 4),
                                Text(
                                  '$streak',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: streak > 0 ? tokens.warning : tokens.textMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Time Coin Chip
                        GestureDetector(
                          onTap: () => context.push('/wallet'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: tokens.coin.withValues(alpha: 0.15),
                              borderRadius: AppRadii.cardRadius,
                              border: Border.all(
                                color: tokens.coin.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.toll_rounded, size: 15, color: tokens.coin),
                                const SizedBox(width: 4),
                                Text(
                                  '$timeCoins',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.coin,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Quick Theme Toggle
                        Tooltip(
                          message: isDark ? 'التبديل إلى الوضع النهاري' : 'التبديل إلى الوضع الليلي',
                          child: InkWell(
                            onTap: () {
                              ref.read(themeModeProvider.notifier).toggleTheme(!isDark);
                            },
                            borderRadius: AppRadii.cardRadius,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: tokens.surfaceAlt,
                                shape: BoxShape.circle,
                                border: Border.all(color: tokens.border),
                              ),
                              child: Icon(
                                isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                                size: 16,
                                color: tokens.warning,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Quick Q&A forum banner
              InkWell(
                onTap: () => context.go('/questions'),
                borderRadius: AppRadii.cardRadius,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: tokens.brandContainer.withValues(alpha: 0.35),
                    borderRadius: AppRadii.cardRadius,
                    border: Border.all(
                      color: tokens.brand.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tokens.brand.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.forum_outlined, color: tokens.brand, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'منتدى الأسئلة والحلول لدفعتك',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: tokens.textHigh,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'تصفح أسئلة زملائك أو اطرح استفسارك الأكاديمي',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: tokens.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_back_ios_rounded, size: 13, color: tokens.textMedium),
                    ],
                  ),
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
                      child: Text(
                        'عرض كل الجلسات',
                        style: TextStyle(fontSize: 12, color: tokens.brand, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      'جلسة تبادل قادمة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: tokens.textHigh,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                InkWell(
                  borderRadius: AppRadii.cardRadius,
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
                      color: tokens.surface,
                      borderRadius: AppRadii.cardRadius,
                      border: Border.all(color: tokens.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: tokens.successContainer,
                                borderRadius: AppRadii.fullRadius,
                              ),
                              child: Text(
                                'مؤكدة',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.success),
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
                                            color: tokens.textHigh,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          confirmedSession.topic,
                                          style: TextStyle(fontSize: 12, color: tokens.textMedium),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  CircleAvatar(
                                    backgroundColor: tokens.brandContainer,
                                    radius: 18,
                                    child: Text(
                                      confirmedSession.teacherId == userId
                                          ? (confirmedSession.learnerName.trim().isNotEmpty
                                              ? confirmedSession.learnerName.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('.')
                                              : 'ز.م')
                                          : confirmedSession.teacherInitials,
                                      style: TextStyle(fontWeight: FontWeight.bold, color: tokens.brand, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(height: 1, color: tokens.border),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: confirmedSession.teacherId == userId
                                    ? tokens.warningContainer
                                    : tokens.dangerContainer,
                                borderRadius: AppRadii.controlRadius,
                              ),
                              child: Text(
                                confirmedSession.teacherId == userId
                                    ? '+${confirmedSession.costCoins} عملة وقت (مكافأة)'
                                    : '-${confirmedSession.costCoins} عملة وقت (في الضمان)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: confirmedSession.teacherId == userId ? tokens.warning : tokens.danger,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '${confirmedSession.day} • ${confirmedSession.time} (${confirmedSession.durationMinutes} دقيقة)',
                                  style: TextStyle(fontSize: 12, color: tokens.textMedium),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.access_time_rounded, size: 14, color: tokens.textLow),
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
                            child: Text(
                              '+ إضافة / تعديل المحاضرات',
                              style: TextStyle(fontSize: 12, color: tokens.brand, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            'جدول اليوم ($totalTodayItems عناصر)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: tokens.textHigh,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (totalTodayItems == 0)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: tokens.surface,
                            borderRadius: AppRadii.cardRadius,
                            border: Border.all(color: tokens.border),
                          ),
                          child: todayArabic == 'الجمعة'
                              ? Column(
                                  children: [
                                    Icon(Icons.weekend_rounded, size: 44, color: tokens.textLow),
                                    const SizedBox(height: 12),
                                    Text(
                                      'عطلة نهاية الأسبوع • يوم الجمعة المبارك',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textHigh),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'لا توجد جلسات مذاكرة أو محاضرات مجدولة اليوم. استمتع بيومك وجدد طاقتك قبل بداية الأسبوع الجديد!',
                                      style: TextStyle(fontSize: 13, color: tokens.textMedium, height: 1.4),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: () => context.push('/plan'),
                                      icon: Icon(Icons.calendar_month_outlined, size: 18),
                                      label: Text('استعراض خطة الأسبوع'),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    Icon(Icons.calendar_today_outlined, size: 40, color: tokens.textLow),
                                    const SizedBox(height: 12),
                                    Text(
                                      'لا توجد محاضرات أو مذاكرة مجدولة اليوم',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.textHigh),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'أضف مواعيد محاضراتك وموادك وسيقوم التطبيق بحساب أوقات فراغك وتوليد خطة مذاكرة ذكية لك تلقائياً.',
                                      style: TextStyle(fontSize: 12, color: tokens.textMedium),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 14),
                                    ElevatedButton.icon(
                                      onPressed: () => context.push('/schedule-setup'),
                                      icon: Icon(Icons.add_rounded, size: 18, color: tokens.onBrand),
                                      label: Text('إعداد جدول المحاضرات الآن', style: TextStyle(color: tokens.onBrand, fontSize: 13, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: tokens.brand,
                                        shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
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
                          ribbonColor: block.isCompleted ? tokens.success : block.ribbonColor,
                          statusText: block.isCompleted ? 'تمت' : 'لم تتم',
                          isDone: block.isCompleted,
                          canToggle: !block.isCompleted,
                          onToggleDone: () {
                            if (block.isCompleted) {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: tokens.brand,
                                  duration: const Duration(seconds: 2),
                                  content: const Text(
                                    'تم إنجاز هذه الجلسة مسبقاً.',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                              return;
                            }

                            // إتمام المهمة الحالية (إتمام دائم غير قابل للتراجع)
                            ref.read(plannerProvider.notifier).markBlockCompleted(block.id);

                            final uid = ref.read(authServiceProvider).currentUser?.uid;
                            if (uid != null && uid.isNotEmpty) {
                              ref.read(timeBankRepositoryProvider).awardStudyPoint(
                                userId: uid,
                                title: 'إتمام مذاكرة: ${block.courseName}',
                                blockId: block.id,
                                points: 1,
                              );
                            }

                            // فحص هل اكتملت جميع مهام اليوم بعد إتمام هذه المهمة
                            final remainingBeforeThis = todayBlocks.where((b) => !b.isCompleted && b.id != block.id).length;
                            final isAllTodayCompleted = remainingBeforeThis == 0;

                            if (isAllTodayCompleted) {
                              // مكافأة إتمام جميع مهام اليوم بنقطة الإنجاز اليومي فوراً
                              final todayKey = 'daily_done_${now.year}_${now.month}_${now.day}';
                              if (uid != null && uid.isNotEmpty) {
                                ref.read(timeBankRepositoryProvider).awardStudyPoint(
                                  userId: uid,
                                  title: 'مكافأة إتمام جميع مهام اليوم',
                                  blockId: todayKey,
                                  points: 1,
                                );
                              }

                              final currentStreak = ref.read(userStreakProvider);

                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: tokens.success,
                                  duration: const Duration(seconds: 4),
                                  content: Row(
                                    children: [
                                      Icon(Icons.local_fire_department_rounded, size: 26, color: tokens.coin),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'أتممت جميع مهام مذاكرة اليوم بنجاح وتقدم تتابعك اليومي ($currentStreak).',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: tokens.success,
                                  duration: const Duration(seconds: 2),
                                  content: Text(
                                    'تم إنجاز "${block.courseName}" بنجاح. متبقي $remainingBeforeThis مهام لإكمال خطة اليوم.',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            }
                          },
                          onTap: () => context.push('/study-block-details', extra: block),
                        );
                      }),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // 5. Progress Card: Daily Goal Ring
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: tokens.border),
                ),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: CircularProgressIndicator(
                            value: dailyProgressPct,
                            strokeWidth: 6,
                            backgroundColor: tokens.surfaceAlt,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              dailyProgressPct >= 1.0 && todayBlocksCount > 0
                                  ? tokens.success
                                  : tokens.brand,
                            ),
                          ),
                        ),
                        Text(
                          '$dailyProgressInt%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: tokens.textHigh,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'معدل إنجاز اليوم',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: tokens.brand),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            todayBlocksCount == 0
                                ? 'لا توجد مهام مذاكرة مجدولة اليوم'
                                : 'أنجزت $todayCompletedCount من $todayBlocksCount مهام اليوم',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: tokens.textHigh,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            todayBlocksCount == 0
                                ? 'استمتع بيومك أو أضف محاضراتك لتوليد الخطة'
                                : (todayRemainingCount == 0
                                    ? 'أتممت جميع مهام اليوم وحافظت على التتابع اليومي ($streak يوم).'
                                    : 'متبقي $todayRemainingCount مهام لتحقيق خطة اليوم ومواصلة التتابع ($streak يوم).'),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: todayRemainingCount == 0 && todayBlocksCount > 0
                                  ? tokens.success
                                  : tokens.textMedium,
                              fontWeight: todayRemainingCount == 0 && todayBlocksCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
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
    final tokens = context.tokens;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: tokens.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.cardRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Course Color Indicator + Course Title + Status Action
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: ribbonColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: tokens.textHigh,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (canToggle)
                      InkWell(
                        onTap: onToggleDone,
                        borderRadius: AppRadii.fullRadius,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDone
                                ? tokens.successContainer
                                : tokens.surfaceAlt,
                            borderRadius: AppRadii.fullRadius,
                            border: Border.all(
                              color: isDone
                                  ? tokens.success.withValues(alpha: 0.4)
                                  : tokens.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                size: 14,
                                color: isDone ? tokens.success : tokens.textLow,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isDone ? 'مكتملة' : 'قيد الانتظار',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDone ? tokens.success : tokens.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: ribbonColor.withValues(alpha: 0.15),
                          borderRadius: AppRadii.controlRadius,
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: ribbonColor,
                          ),
                        ),
                      ),
                  ],
                ),

                // Row 2: Topic Description (if available)
                if (category.trim().isNotEmpty && category != 'محاضرة رسمية') ...[
                  const SizedBox(height: 8),
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: tokens.textMedium,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 10),

                // Row 3: Metadata Badges (Time & Location)
                Row(
                  children: [
                    // Time Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: tokens.surfaceAlt,
                        borderRadius: AppRadii.controlRadius,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_rounded, size: 13, color: tokens.textLow),
                          const SizedBox(width: 4),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: tokens.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (room.trim().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      // Location Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: tokens.surfaceAlt,
                          borderRadius: AppRadii.controlRadius,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_outlined, size: 13, color: tokens.textLow),
                            const SizedBox(width: 4),
                            Text(
                              room,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: tokens.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Spacer(),

                    Icon(Icons.arrow_back_ios_rounded, size: 12, color: tokens.textLow),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}