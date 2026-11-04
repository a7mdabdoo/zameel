// مطور 3
// فيجما: بنك الوقت: جلساتي - ذاكر وعلّم

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class MySessionsScreen extends StatefulWidget {
  const MySessionsScreen({super.key});

  @override
  State<MySessionsScreen> createState() => _MySessionsScreenState();
}

class _MySessionsScreenState extends State<MySessionsScreen> {
  int _activeRoleIndex = 0; // 0: كمتعلّم (أستقبل شرح), 1: كشارح (أنا الشارح)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'جلساتي المحجوزة 📅',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                            'جلساتي كمتعلّم (1)',
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
                            'جلساتي كشارح (1)',
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
                    // Learner card -> /session-learner
                    _buildSessionCard(
                      partnerName: 'عمر خالد (الشارح)',
                      partnerInitials: 'ع.خ',
                      courseName: 'الجبر الخطي (Linear Algebra)',
                      topic: 'الفضاءات المتجهة والتحويلات الخطية',
                      time: 'الخميس • 4:00 م (60 دقيقة)',
                      location: 'معمل 3 • الكلية',
                      badgeText: 'مؤكدة',
                      badgeColor: AppColors.deepSage,
                      costText: '-1 عملة وقت',
                      costColor: AppColors.error,
                      actionLabel: 'تفاصيل الجلسة وتأكيد الإتمام',
                      onAction: () => context.push('/session-learner'),
                    ),
                  ] else ...[
                    // Teacher card -> /session-teacher
                    _buildSessionCard(
                      partnerName: 'زياد ناصح (المتعلّم)',
                      partnerInitials: 'ز.ن',
                      courseName: 'البرمجة الكائنية (OOP)',
                      topic: 'شرح الـ Inheritance والـ Polymorphism',
                      time: 'الأربعاء • 12:00 ظهراً (60 دقيقة)',
                      location: 'مكتبة الكلية • الطابق الثاني',
                      badgeText: 'طلب وارد',
                      badgeColor: AppColors.primary,
                      costText: '+1 عملة وقت',
                      costColor: AppColors.pointsAmber,
                      actionLabel: 'تفاصيل الجلسة وبدء الشرح',
                      onAction: () => context.push('/session-teacher'),
                    ),
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
        color: Colors.white,
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
                      Text(partnerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
