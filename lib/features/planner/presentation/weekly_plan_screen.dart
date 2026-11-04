// مطور 3
// فيجما: الخطة الأسبوعية - ذاكر وعلّم

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class WeeklyPlanScreen extends StatefulWidget {
  const WeeklyPlanScreen({super.key});

  @override
  State<WeeklyPlanScreen> createState() => _WeeklyPlanScreenState();
}

class _WeeklyPlanScreenState extends State<WeeklyPlanScreen> {
  int _selectedDayIndex = 0;
  final List<String> _days = ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'الخطة الأسبوعية 📅',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
            onPressed: () => context.push('/schedule-setup'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/schedule-setup'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'إضافة لمواعيدي',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Days horizontal selector
            Container(
              height: 56,
              color: AppColors.surface,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _days.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedDayIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDayIndex = index),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          _days[index],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Plan overview stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMiniStatCard('جلسات اليوم', '3 جلسات', AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniStatCard('ساعات المذاكرة', '2.5 ساعة', AppColors.deepSage),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniStatCard('أوقات الفراغ', '3 ساعات', AppColors.pointsAmber),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Weekly schedule blocks
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildPlanBlock(
                    title: 'محاضرة: تنظيم الحواسب (Computer Org)',
                    time: '08:30 ص – 10:00 ص',
                    location: 'مدرج 2',
                    ribbonColor: AppColors.courseDustPlum,
                    type: 'محاضرة رسمية',
                  ),
                  _buildPlanBlock(
                    title: 'مذاكرة: هياكل البيانات (Data Structures)',
                    time: '11:00 ص – 11:45 ص',
                    location: 'المكتبة • الأشجار الثنائية',
                    ribbonColor: AppColors.courseSage,
                    type: 'مذاكرة ذكية',
                    isInteractive: true,
                  ),
                  _buildPlanBlock(
                    title: 'جلسة بنك الوقت: مع عمر خالد',
                    time: '01:30 م – 02:30 م',
                    location: 'معمل 3 • الجبر الخطي',
                    ribbonColor: AppColors.courseClay,
                    type: 'جلسة أقران',
                    isTimeBank: true,
                  ),
                  _buildPlanBlock(
                    title: 'مذاكرة: قواعد البيانات (Databases)',
                    time: '04:00 م – 04:45 م',
                    location: 'المنزل • تمارين SQL',
                    ribbonColor: AppColors.courseSand,
                    type: 'مذاكرة ذكية',
                    isInteractive: true,
                  ),
                  const SizedBox(height: 70), // space for FAB
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildPlanBlock({
    required String title,
    required String time,
    required String location,
    required Color ribbonColor,
    required String type,
    bool isInteractive = false,
    bool isTimeBank = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
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
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (isTimeBank) {
            context.push('/session-learner');
          } else {
            context.push('/study-block-details');
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 5, color: ribbonColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: ribbonColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ribbonColor),
                              ),
                            ),
                            Text(time, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text(location, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const Spacer(),
                            const Icon(Icons.arrow_back_ios_rounded, size: 12, color: AppColors.textTertiary),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
