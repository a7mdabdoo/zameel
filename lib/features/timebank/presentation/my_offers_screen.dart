// مطور 3
// فيجما: بنك الوقت: عروضي - ذاكر وعلّم

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/auth/data/auth_service.dart';
import '../../../features/timebank/data/timebank_repository.dart';

class MyOffersScreen extends ConsumerStatefulWidget {
  const MyOffersScreen({super.key});

  @override
  ConsumerState<MyOffersScreen> createState() => _MyOffersScreenState();
}

class _MyOffersScreenState extends ConsumerState<MyOffersScreen> {
  int _selectedTab = 0; // 0: عروضي, 1: جلساتي, 2: أحتاج مساعدة

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    final userId = user?.uid ?? '';

    final liveOffersAsync = ref.watch(userOffersStreamProvider(userId));
    final offers = liveOffersAsync.value ?? [];

    final learnerSessionsAsync = ref.watch(learnerSessionsStreamProvider(userId));
    final teacherSessionsAsync = ref.watch(teacherSessionsStreamProvider(userId));
    final totalSessionsCount = (learnerSessionsAsync.value?.length ?? 0) + (teacherSessionsAsync.value?.length ?? 0);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardTheme.color,
        elevation: 0,
        title: Text(
          'بنك الوقت الأكاديمي ⏱️',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/create-offer'),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'أضف عرضاً للشرح',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Tabs Bar
            Container(
              color: Theme.of(context).cardTheme.color,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildTabItem(0, 'عروضي (${offers.length})'),
                  const SizedBox(width: 8),
                  _buildTabItem(1, 'جلساتي ($totalSessionsCount)'),
                  const SizedBox(width: 8),
                  _buildTabItem(2, 'طلب مساعدة'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: _selectedTab == 0
                  ? _buildMyOffersList(offers)
                  : _selectedTab == 1
                      ? _buildRedirectToSessions()
                      : _buildRedirectToNeedHelp(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String title) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (index == 1) {
            context.push('/my-sessions');
          } else if (index == 2) {
            context.push('/need-help');
          } else {
            setState(() => _selectedTab = index);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyOffersList(List<dynamic> offers) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Balance info
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.volunteer_activism_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'عندما يشترك زميل في عرضك وتشرح له، تكسب 1 عملة وقت في محفظتك تلقائياً!',
                  style: TextStyle(fontSize: 12, color: AppColors.primary, height: 1.4),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (offers.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
              child: Column(
                children: [
                  const Icon(Icons.school_outlined, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد لديك عروض شرح حالياً',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'شارك معرفتك مع زملائك واكسب عملات وقت لطلب المساعدة في المواد التي تحتاجها.\nاضغط على الزر بالأسفل لإضافة أول عرض شرح.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ),

        // Active offers list
        ...offers.map((offer) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border(
                right: BorderSide(color: offer.courseColor as Color, width: 6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.sage.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'متاح للحجز',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.deepSage),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('حذف عرض الشرح'),
                                content: Text('هل تريد حذف عرضك لشرح "${offer.courseName}"؟'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await ref.read(timeBankRepositoryProvider).deleteOffer(offer.id);
                            }
                          },
                        ),
                      ],
                    ),
                    Text(
                      offer.courseName as String,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  offer.topic as String,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 6),
                    Text(
                      '${offer.day} • ${offer.time} (${offer.durationMinutes} دقيقة)',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    const Text('+1 عملة وقت', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.pointsAmber)),
                  ],
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildRedirectToSessions() {
    return Center(
      child: ElevatedButton(
        onPressed: () => context.push('/my-sessions'),
        child: const Text('الانتقال إلى جلساتي'),
      ),
    );
  }

  Widget _buildRedirectToNeedHelp() {
    return Center(
      child: ElevatedButton(
        onPressed: () => context.push('/need-help'),
        child: const Text('الانتقال إلى طلب مساعدة'),
      ),
    );
  }
}
