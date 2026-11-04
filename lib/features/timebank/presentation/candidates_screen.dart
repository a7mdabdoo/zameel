// مطور 3
// فيجما: المرشحون للمساعدة - ذاكر وعلّم (خوارزمية تقاطع الفترات التوافقية)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';

class CandidatesScreen extends ConsumerWidget {
  const CandidatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(peerMatchesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_forward_ios_rounded, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'المرشحون للمساعدة 🎯 (${matches.length} زملاء)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final match = matches[index];
            final teacher = match.teacher;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top row: match badge & Peer info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'توافق ${match.matchScore}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                teacher.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '(${teacher.totalReviews} جلسة شرح)',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${teacher.rating}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.star_rounded, size: 16, color: AppColors.pointsAmber),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.primaryContainer,
                            child: Text(
                              teacher.initials,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Text(
                    teacher.bioNote,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),

                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_filled_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'الموعد المشترك: ${match.bestSlotFormatted}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Button "اعرض واحجز" -> /booking
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/booking'),
                      icon: const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 18),
                      label: const Text(
                        'عرض تفاصيل الحجز',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
