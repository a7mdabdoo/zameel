// مطور 3
// فيجما: بنك الوقت: جلساتي - ذاكر وعلّم

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../features/auth/data/auth_service.dart';
import '../../../features/timebank/data/timebank_repository.dart';

class MySessionsScreen extends ConsumerStatefulWidget {
  const MySessionsScreen({super.key});

  @override
  ConsumerState<MySessionsScreen> createState() => _MySessionsScreenState();
}

class _MySessionsScreenState extends ConsumerState<MySessionsScreen> {
  int _activeRoleIndex = 0; // 0: كمتعلّم (أستقبل شرح), 1: كشارح (أنا الشارح)

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    final userId = user?.uid ?? '';

    final learnerSessionsAsync = ref.watch(learnerSessionsStreamProvider(userId));
    final teacherSessionsAsync = ref.watch(teacherSessionsStreamProvider(userId));

    final learnerSessions = learnerSessionsAsync.value ?? [];
    final teacherSessions = teacherSessionsAsync.value ?? [];

    final tokens = context.tokens;
    final surfaceAlt = tokens.surfaceAlt;
    final cardColor = tokens.surface;
    final primaryColor = tokens.brand;

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
          'جلساتي',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Role Selector Tab
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: surfaceAlt,
                  borderRadius: AppRadii.cardRadius,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _activeRoleIndex = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _activeRoleIndex == 0 ? cardColor : Colors.transparent,
                            borderRadius: AppRadii.controlRadius,
                            boxShadow: _activeRoleIndex == 0
                                ? tokens.floatingShadow
                                : null,
                          ),
                          child: Text(
                            'جلساتي كمتعلّم (${learnerSessions.length})',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _activeRoleIndex == 0 ? FontWeight.bold : FontWeight.normal,
                              color: _activeRoleIndex == 0 ? primaryColor : tokens.textMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _activeRoleIndex = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _activeRoleIndex == 1 ? cardColor : Colors.transparent,
                            borderRadius: AppRadii.controlRadius,
                            boxShadow: _activeRoleIndex == 1
                                ? tokens.floatingShadow
                                : null,
                          ),
                          child: Text(
                            'جلساتي كشارح (${teacherSessions.length})',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _activeRoleIndex == 1 ? FontWeight.bold : FontWeight.normal,
                              color: _activeRoleIndex == 1 ? primaryColor : tokens.textMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                children: [
                  if (_activeRoleIndex == 0) ...[
                    if (learnerSessions.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('لا توجد جلسات حجز حالياً كمتعلّم'),
                        ),
                      )
                    else
                      ...learnerSessions.map((session) {
                        final isCompleted = session.status == 'completed' || session.status == 'completed_auto' || session.escrowStatus == 'released_to_teacher';
                        final isCancelled = session.status.startsWith('cancelled') || session.status == 'rejected' || session.status == 'expired' || session.escrowStatus == 'refunded_to_learner';
                        final isPending = session.status == 'pending';
                        
                        String badge = 'مؤكدة';
                        Color bColor = tokens.brand;
                        if (isPending) {
                          badge = 'بانتظار الموافقة';
                          bColor = tokens.warning;
                        } else if (isCompleted) {
                          badge = 'مكتملة';
                          bColor = tokens.brand;
                        } else if (isCancelled) {
                          badge = session.status == 'rejected' ? 'معتذر عنها' : (session.status == 'expired' ? 'منتهية' : 'ملغاة');
                          bColor = tokens.danger;
                        }

                        return _buildSessionCard(
                          partnerName: '${session.teacherName} (الشارح)',
                          partnerInitials: session.teacherInitials,
                          courseName: '${session.courseName} (${session.courseCode})',
                          topic: session.topic,
                          time: '${session.day} • ${session.time} (${session.durationMinutes} دقيقة)',
                          location: session.mode == 'online' ? 'أونلاين (عن بُعد)' : session.location,
                          badgeText: badge,
                          badgeColor: bColor,
                          costText: '-${session.costCoins} عملة وقت',
                          costColor: tokens.danger,
                          actionLabel: isCompleted
                              ? 'عرض تقييم الجلسة'
                              : (isCancelled ? 'تفاصيل الجلسة' : (isPending ? 'تفاصيل الطلب وإلغاءه' : 'تفاصيل الجلسة وتأكيد الإتمام')),
                          onAction: () => context.push('/session-learner', extra: session),
                        );
                      }),
                  ] else ...[
                    if (teacherSessions.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('لا توجد جلسات شرح واردة لك حالياً'),
                        ),
                      )
                    else
                      ...teacherSessions.map((session) {
                        final isCompleted = session.status == 'completed' || session.status == 'completed_auto' || session.escrowStatus == 'released_to_teacher';
                        final isCancelled = session.status.startsWith('cancelled') || session.status == 'rejected' || session.status == 'expired' || session.escrowStatus == 'refunded_to_learner';
                        final isPending = session.status == 'pending';

                        String badge = 'مؤكدة (في الضمان)';
                        Color bColor = tokens.brand;
                        if (isPending) {
                          badge = 'طلب جديد';
                          bColor = tokens.warning;
                        } else if (isCompleted) {
                          badge = 'مكتملة';
                          bColor = tokens.brand;
                        } else if (isCancelled) {
                          badge = session.status == 'rejected' ? 'معتذر عنها' : (session.status == 'expired' ? 'منتهية' : 'ملغاة');
                          bColor = tokens.danger;
                        }

                        final isMissingMeetingLink = session.mode == 'online' &&
                            (session.meetingUrl == null || session.meetingUrl!.isEmpty) &&
                            session.escrowStatus == 'held' &&
                            session.status == 'confirmed';

                        return _buildSessionCard(
                          partnerName: '${session.learnerName} (المتعلّم)',
                          partnerInitials: session.teacherInitials,
                          courseName: session.courseName,
                          topic: session.topic,
                          time: '${session.day} • ${session.time} (${session.durationMinutes} دقيقة)',
                          location: session.mode == 'online' ? 'أونلاين (عن بُعد)' : session.location,
                          badgeText: badge,
                          badgeColor: bColor,
                          costText: '+${session.costCoins} عملة وقت',
                          costColor: tokens.coin,
                          showMissingMeetingLinkBanner: isMissingMeetingLink,
                          actionLabel: isCompleted
                              ? 'الجلسة مكتملة ومقبوضة'
                              : (isCancelled ? 'تفاصيل الإلغاء' : (isPending ? 'مراجعة الطلب والقبول' : 'تفاصيل الجلسة وبدء الشرح')),
                          onAction: () => context.push('/session-teacher', extra: session),
                        );
                      }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard({
    required String partnerName,
    required String partnerInitials,
    required String courseName,
    required String topic,
    required String time,
    required String location,
    required String badgeText,
    required Color badgeColor,
    required String costText,
    required Color costColor,
    required String actionLabel,
    required VoidCallback onAction,
    bool showMissingMeetingLinkBanner = false,
  }) {
    final tokens = context.tokens;
    final hairline = tokens.border;
    final surfaceAlt = tokens.surfaceAlt;
    final primaryColor = tokens.brand;
    final primaryContainer = tokens.brandContainer;
    final textSecondary = tokens.textMedium;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: hairline),
        boxShadow: [
          BoxShadow(
            color: tokens.scrim.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showMissingMeetingLinkBanner) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: AppRadii.controlRadius,
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'أضف رابط الاجتماع (Google Meet / Zoom)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                  ),
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('إضافة الآن', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: AppRadii.controlRadius,
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        partnerName,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                      ),
                      Text(courseName, style: TextStyle(fontSize: 11, color: textSecondary)),
                    ],
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: primaryContainer,
                    child: Text(partnerInitials, style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(topic, style: TextStyle(fontSize: 13, color: textSecondary)),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: surfaceAlt,
              borderRadius: AppRadii.controlRadius,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(costText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: costColor)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$time • $location',
                    style: TextStyle(fontSize: 11, color: textSecondary),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
