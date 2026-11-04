// مطور 3
// فيجما: اليوم - ذاكر وعلّم

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../auth/data/auth_service.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final userDoc = userProfileAsync.value?.data();
    final userName = userDoc?['name'] as String? ?? 'أحمد';

    final plannerState = ref.watch(plannerProvider);
    final timeBankState = ref.watch(timeBankProvider);

    final timeCoins = timeBankState.activeTimeCoins;
    final todayBlocks = plannerState.studyBlocks.where((b) => b.day == 'السبت').toList();
    final nextBlock = todayBlocks.isNotEmpty ? todayBlocks.first : null;
    final confirmedSession = timeBankState.sessions.isNotEmpty ? timeBankState.sessions.first : null;

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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF664700),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'نقاط وقت',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF664700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Greeting & Date
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'صباح الخير يا $userName 👋',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Row(
                          children: [
                            Text(
                              'اليوم • السبت، 14 نوفمبر',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textTertiary),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Next Up Highlight Card (بطاقة الجلسة القادمة)
              if (nextBlock != null)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.hairline),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.school_outlined, size: 18, color: AppColors.primary),
                          ),
                          Row(
                            children: [
                              const Text(
                                'جلسة تركيز فردية',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.sage.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppColors.deepSage,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'التالي',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.deepSage,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        nextBlock.courseName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${nextBlock.topic} • المدة: ${nextBlock.durationMinutes} دقيقة • ${nextBlock.startTime}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Active Action CTA Button -> /study-block-details
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/study-block-details'),
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                          label: const Text(
                            'ابدأ الآن',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // 3. Section: Time Bank Peer Exchange Card (جلسة الأقران المحجوزة)
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
                  onTap: () => context.push('/session-learner'),
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
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${confirmedSession.teacherName} يشرح لك ${confirmedSession.courseName}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      confirmedSession.topic,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                CircleAvatar(
                                  backgroundColor: AppColors.primaryContainer,
                                  radius: 20,
                                  child: Text(
                                    confirmedSession.teacherInitials,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                                  ),
                                ),
                              ],
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
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '-${confirmedSession.costCoins} عملة وقت',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => context.push('/schedule-setup'),
                    child: const Text(
                      '+ إضافة موعد',
                      style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    'جدول اليوم (${todayBlocks.length + 1} عناصر)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Lecture 1
              _buildTimelineItem(
                context: context,
                title: 'التفاضل والتكامل (Calculus)',
                category: 'محاضرة رسمية',
                room: 'قاعة 3',
                time: '9:00 ص – 10:30 ص',
                ribbonColor: AppColors.courseSlate,
                statusText: 'تمت',
                isDone: true,
                onTap: () => context.push('/study-block-details'),
              ),

              // Dynamic Blocks from Greedy Algorithm
              ...todayBlocks.map((block) {
                return _buildTimelineItem(
                  context: context,
                  title: block.courseName,
                  category: block.topic,
                  room: block.room,
                  time: '${block.startTime} – ${block.endTime}',
                  ribbonColor: block.ribbonColor,
                  statusText: block.isCompleted ? 'مكتملة' : 'مخطط لها',
                  isDone: block.isCompleted,
                  onTap: () => context.push('/study-block-details'),
                );
              }),

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
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
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
                        Text(
                          '$category • $room',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
