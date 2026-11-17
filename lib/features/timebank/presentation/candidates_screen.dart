// مطور 3
// فيجما: المرشحون للمساعدة - ذاكر وعلّم (خوارزمية تقاطع الفترات التوافقية)

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../features/timebank/data/timebank_repository.dart';

class CandidatesScreen extends ConsumerWidget {
  final CourseSeed? targetCourse;
  const CandidatesScreen({super.key, this.targetCourse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayOffers = ref.watch(peerCandidatesProvider(targetCourse));

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
          targetCourse != null
              ? 'المرشحون: ${targetCourse!.name}'
              : 'المرشحون للمساعدة 🎯 (${displayOffers.length})',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: displayOffers.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 72, color: AppColors.textSecondary),
                      const SizedBox(height: 18),
                      Text(
                        'لا يوجد عروض شرح متاحة حالياً لهذه المادة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'يمكن لزميلك الدخول من حسابه والضغط على "أضف عرضاً للشرح" في مادة "${targetCourse?.name ?? 'المادة'}"، وسيظهر لك عرضه هنا فوراً لحجز الجلسة معه!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                        label: const Text('العودة لاختيار مادة أخرى', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                itemCount: displayOffers.length,
                itemBuilder: (context, index) {
                  final theme = Theme.of(context);
                  final isDark = theme.brightness == Brightness.dark;
                  final offer = displayOffers[index];
                  final isRealPeer = !offer.id.startsWith('offer_peer_');
                  final isOnline = offer.mode == 'online';
                  final teacherInitials = offer.teacherName.trim().isNotEmpty
                      ? offer.teacherName.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('.')
                      : 'ز.م';

                  final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
                  final primaryContainer = isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer;
                  final surfaceAlt = isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt;
                  final hairline = isDark ? AppColors.darkHairline : AppColors.hairline;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isRealPeer ? (isDark ? AppColors.darkPrimary.withValues(alpha: 0.4) : AppColors.deepSage.withValues(alpha: 0.4)) : hairline,
                        width: isRealPeer ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top row: badge & Peer info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isRealPeer
                                        ? (isDark ? AppColors.darkPrimary.withValues(alpha: 0.2) : AppColors.sage.withValues(alpha: 0.2))
                                        : primaryContainer.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    border: isRealPeer
                                        ? Border.all(color: (isDark ? AppColors.darkPrimary : AppColors.deepSage).withValues(alpha: 0.3))
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isRealPeer ? Icons.stars_rounded : Icons.verified_user_rounded,
                                        size: 14,
                                        color: isRealPeer ? (isDark ? AppColors.darkPrimary : AppColors.deepSage) : primaryColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isRealPeer ? 'زميل بالدفعة 🌟' : 'مرشح أكاديمي',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isRealPeer ? (isDark ? AppColors.darkPrimary : AppColors.deepSage) : primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isOnline) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '💻 أونلاين',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryColor),
                                    ),
                                  ),
                                ],
                                if (offer.isGroupSession) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '👥 جماعية (${offer.enrolledLearnerIds.length}/${offer.maxLearners ?? 10})',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                  ),
                                ],
                                if (offer.isFlexibleRange) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.pointsAmber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      '⏳ موعد مرن',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.pointsAmber),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      offer.teacherName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      'زميل دراسة • كلية الحاسبات',
                                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: primaryContainer,
                                  child: Text(
                                    teacherInitials,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        Text(
                          offer.topic,
                          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface, height: 1.4),
                        ),

                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isOnline ? Icons.videocam_rounded : Icons.access_time_filled_rounded,
                                size: 16,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isOnline
                                      ? 'الموعد: ${offer.day} • ${offer.time} (أونلاين عبر الرابط 💻)'
                                      : 'الموعد: ${offer.day} • ${offer.time} (${offer.location})',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Button "عرض تفاصيل الحجز" -> /booking
                        SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/booking', extra: offer),
                            icon: const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 18),
                            label: const Text(
                              'عرض تفاصيل الحجز',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
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
