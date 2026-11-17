// مطور 3
// فيجما: بنك الوقت: عروضي - ذاكر وعلّم

import 'package:material_ui/material_ui.dart';
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardTheme.color,
        elevation: 0,
        title: Text(
          'بنك الوقت الأكاديمي ⏱️',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
      ),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton.extended(
              heroTag: 'fab_timebank_offers',
              onPressed: () => context.push('/create-offer'),
              backgroundColor: primaryColor,
              icon: Icon(Icons.add, color: isDark ? AppColors.darkOnPrimary : Colors.white),
              label: Text(
                'أضف عرضاً للشرح',
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppColors.darkOnPrimary : Colors.white),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Tabs Bar
            Container(
              color: theme.cardTheme.color,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildTabItem(0, 'عروضي (${offers.length})', isDark, primaryColor),
                  const SizedBox(width: 8),
                  _buildTabItem(1, 'جلساتي ($totalSessionsCount)', isDark, primaryColor),
                  const SizedBox(width: 8),
                  _buildTabItem(2, 'طلب مساعدة', isDark, primaryColor),
                ],
              ),
            ),

            // Academic Q&A Banner
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: InkWell(
                onTap: () => context.push('/questions'),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1B3B2B), const Color(0xFF142B20)]
                          : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.help_center_outlined, color: primaryColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'منتدى الأسئلة والحلول الأكاديمي 💡',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const Text(
                              'اسأل دفعتك أو شارك بالحلول المعتمدة',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: primaryColor),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: _selectedTab == 0
                  ? _buildMyOffersList(offers, isDark, primaryColor)
                  : _selectedTab == 1
                      ? _buildRedirectToSessions()
                      : _buildRedirectToNeedHelp(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String title, bool isDark, Color primaryColor) {
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
            color: isSelected
                ? primaryColor
                : (isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt),
            borderRadius: BorderRadius.circular(12),
            border: isDark && !isSelected
                ? Border.all(color: AppColors.darkHairline)
                : null,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? (isDark ? AppColors.darkOnPrimary : Colors.white)
                  : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyOffersList(List<dynamic> offers, bool isDark, Color primaryColor) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.primary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textTertiary = isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Balance info banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkPrimaryContainer.withValues(alpha: 0.45)
                : AppColors.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primaryColor.withValues(alpha: isDark ? 0.4 : 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.volunteer_activism_rounded, color: primaryColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'عندما يشترك زميل في عرضك وتشرح له، تكسب 1 عملة وقت في محفظتك تلقائياً!',
                  style: TextStyle(
                    fontSize: 13,
                    color: textPrimary,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
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
                  Icon(Icons.school_outlined, size: 64, color: textSecondary),
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
                  Text(
                    'شارك معرفتك مع زملائك واكسب عملات وقت لطلب المساعدة في المواد التي تحتاجها.\nاضغط على الزر بالأسفل لإضافة أول عرض شرح.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
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
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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
                            color: isDark
                                ? AppColors.darkPrimary.withValues(alpha: 0.15)
                                : AppColors.sage.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'متاح للحجز',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkPrimary : AppColors.deepSage,
                            ),
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        offer.courseName as String,
                        textAlign: TextAlign.start,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  offer.topic as String,
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: textTertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${offer.day} • ${offer.time} (${offer.durationMinutes} دقيقة)',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
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
