// مطور 2
// فيجما: حسابي - ذاكر وعلّم

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _darkMode = false;
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final userDoc = userProfileAsync.value?.data();
    final userName = userDoc?['name'] as String? ?? 'أحمد محمود';
    final userEmail = userDoc?['email'] as String? ?? 'ahmed@fci.edu.eg';
    final faculty = userDoc?['faculty'] as String? ?? 'كلية الحاسبات والذكاء الاصطناعي';
    final year = userDoc?['year'] as String? ?? 'الفرقة الثانية';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'الملف الشخصي 👤',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
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
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(
                        userName.isNotEmpty ? userName.substring(0, 1) : 'أ',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userEmail,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$faculty • $year',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Academic Badges & Stats
              Row(
                children: [
                  Expanded(
                    child: _buildBadgeCard('جلسات مكتملة', '7 جلسات', Icons.check_circle_outline, AppColors.deepSage),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBadgeCard('تقييم الأقران', '4.9 ★', Icons.star_outline_rounded, AppColors.pointsAmber),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBadgeCard('ساعات المذاكرة', '14 ساعة', Icons.timer_outlined, AppColors.primary),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Settings List
              const Text(
                'إعدادات التطبيق ⚙️',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('الوضع الليلي (Dark Theme)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('تبديل مظهر الشاشات للألوان الداكنة', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      secondary: const Icon(Icons.dark_mode_outlined, color: AppColors.primary),
                      value: _darkMode,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() => _darkMode = val);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(val ? 'تم تفعيل الوضع الداكن' : 'تم تفعيل الوضع الفاتح')),
                        );
                      },
                    ),
                    const Divider(height: 1, color: AppColors.hairline),
                    SwitchListTile(
                      title: const Text('تنبيهات المذاكرة والجلسات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('إشعارات قبل بدء المواعيد بـ 15 دقيقة', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      secondary: const Icon(Icons.notifications_none_rounded, color: AppColors.primary),
                      value: _notifications,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) => setState(() => _notifications = val),
                    ),
                    const Divider(height: 1, color: AppColors.hairline),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.textSecondary),
                      title: const Text('سياسة الخصوصية وبنك الساعات', style: TextStyle(fontSize: 14)),
                      trailing: const Icon(Icons.arrow_back_ios_rounded, size: 14, color: AppColors.textTertiary),
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Sign Out Button -> /welcome
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) {
                    context.go('/welcome');
                  }
                },
                icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                label: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
