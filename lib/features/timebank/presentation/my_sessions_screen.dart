// مطور 3
// فيجما: بنك الوقت: جلساتي - ذاكر وعلّم

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';

class MySessionsScreen extends ConsumerStatefulWidget {
  const MySessionsScreen({super.key});

  @override
  ConsumerState<MySessionsScreen> createState() => _MySessionsScreenState();
}

class _MySessionsScreenState extends ConsumerState<MySessionsScreen> {
  int _activeRoleIndex = 0; // 0: كمتعلّم (أستقبل شرح), 1: كشارح (أنا الشارح)

  @override
  Widget build(BuildContext context) {
    final timeBankState = ref.watch(timeBankProvider);
    final learnerSessions = timeBankState.sessions.where((s) => s.learnerId == 'current_user').toList();
    final teacherSessions = timeBankState.sessions.where((s) => s.teacherId == 'current_user').toList();

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
          'جلساتي المحجوزة 📅',
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
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _activeRoleIndex = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _activeRoleIndex == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _activeRoleIndex == 0
                                ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                                : null,
                          ),
                          child: Text(
                            'جلساتي كمتعلّم (${learnerSessions.length})',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _activeRoleIndex == 0 ? FontWeight.bold : FontWeight.normal,
                              color: _activeRoleIndex == 0 ? AppColors.primary : AppColors.textSecondary,
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
                            color: _activeRoleIndex == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _activeRoleIndex == 1
                                ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                                : null,
                          ),
                          child: Text(
                            'جلساتي كشارح (${teacherSessions.length})',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _activeRoleIndex == 1 ? FontWeight.bold : FontWeight.normal,
                              color: _activeRoleIndex == 1 ? AppColors.primary : AppColors.textSecondary,
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
                        return _buildSessionCard(
                          partnerName: '${session.teacherName} (الشارح)',
                          partnerInitials: session.teacherInitials,
                          courseName: '${session.courseName} (${session.courseCode})',
                          topic: session.topic,
                          time: '${session.day} • ${session.time} (${session.durationMinutes} دقيقة)',
                          location: session.location,
                          badgeText: session.status == 'completed' ? 'مكتملة ✓' : 'مؤكدة',
                          badgeColor: session.status == 'completed' ? AppColors.primary : AppColors.deepSage,
                          costText: '-${session.costCoins} عملة وقت',
                          costColor: AppColors.error,
                          actionLabel: session.status == 'completed'
                              ? 'تم تقييم الجلسة وتحويل الرصيد'
                              : 'تفاصيل الجلسة وتأكيد الإتمام',
                          onAction: () => context.push('/session-learner'),
                        );
                      }),
                  ] else ...[
                    if (teacherSessions.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('لا توجد طلبات جلسات شرح واردة حالياً'),
                        ),
                      )
                    else
                      ...teacherSessions.map((session) {
                        return _buildSessionCard(
                          partnerName: '${session.learnerName} (المتعلّم)',
                          partnerInitials: session.teacherInitials,
                          courseName: session.courseName,
                          topic: session.topic,
                          time: '${session.day} • ${session.time} (${session.durationMinutes} دقيقة)',
                          location: session.location,
                          badgeText: 'طلب وارد',
                          badgeColor: AppColors.primary,
                          costText: '+${session.costCoins} عملة وقت',
                          costColor: AppColors.pointsAmber,
                          actionLabel: 'تفاصيل الجلسة وبدء الشرح',
                          onAction: () => context.push('/session-teacher'),
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
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
                      Text(courseName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(partnerInitials, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(topic, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(costText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: costColor)),
                Text('$time • $location', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
