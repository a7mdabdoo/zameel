// مطور 3
// فيجما: الخطة الأسبوعية - ذاكر وعلّم

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';

class WeeklyPlanScreen extends ConsumerStatefulWidget {
  const WeeklyPlanScreen({super.key});

  @override
  ConsumerState<WeeklyPlanScreen> createState() => _WeeklyPlanScreenState();
}

class _WeeklyPlanScreenState extends ConsumerState<WeeklyPlanScreen> {
  int _selectedDayIndex = 0;
  final List<String> _days = ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];

  @override
  Widget build(BuildContext context) {
    final plannerState = ref.watch(plannerProvider);
    final currentDay = _days[_selectedDayIndex];
    final dayBlocks = plannerState.studyBlocks.where((b) => b.day == currentDay).toList();
    final dayLectures = plannerState.lectureSchedule.where((l) => l.day == currentDay).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardTheme.color,
        elevation: 0,
        title: Text(
          'الخطة الأسبوعية 📅',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
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
              color: Theme.of(context).cardTheme.color,
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
                    child: _buildMiniStatCard('جلسات اليوم', '${dayBlocks.length} جلسات', AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniStatCard('محاضرات رسمية', '${dayLectures.length} محاضرات', AppColors.deepSage),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniStatCard('إنجاز الأسبوع', '${(plannerState.progressPercentage * 100).round()}%', AppColors.pointsAmber),
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
                  // Lectures
                  ...dayLectures.map((lec) {
                    return _buildPlanBlock(
                      title: 'محاضرة: ${lec.courseName}',
                      time: '${lec.startTime} – ${lec.endTime}',
                      location: lec.room,
                      ribbonColor: lec.color,
                      type: 'محاضرة رسمية',
                    );
                  }),

                  // Study Blocks generated by Greedy Planner Algorithm
                  ...dayBlocks.map((block) {
                    return _buildPlanBlock(
                      title: 'مذاكرة: ${block.courseName}',
                      time: '${block.startTime} – ${block.endTime}',
                      location: '${block.room} • ${block.topic}',
                      ribbonColor: block.ribbonColor,
                      type: block.isCompleted ? 'مكتملة ✓' : 'مذاكرة ذكية',
                      isInteractive: true,
                    );
                  }),

                  if (dayLectures.isEmpty && dayBlocks.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('يوم راحة أو لا توجد مواعيد مسجلة'),
                      ),
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
        color: Theme.of(context).cardTheme.color,
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          context.push('/study-block-details');
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
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
