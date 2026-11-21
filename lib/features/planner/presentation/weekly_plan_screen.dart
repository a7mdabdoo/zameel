// مطور 3
// فيجما: الخطة الأسبوعية - ذاكر وعلّم

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/state/app_state.dart';

class WeeklyPlanScreen extends ConsumerStatefulWidget {
  const WeeklyPlanScreen({super.key});

  @override
  ConsumerState<WeeklyPlanScreen> createState() => _WeeklyPlanScreenState();
}

class _WeeklyPlanScreenState extends ConsumerState<WeeklyPlanScreen> {
  int _selectedDayIndex = 0;
  final List<String> _days = ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];

  @override
  void initState() {
    super.initState();
    final dayNames = {
      DateTime.saturday: 'السبت',
      DateTime.sunday: 'الأحد',
      DateTime.monday: 'الاثنين',
      DateTime.tuesday: 'الثلاثاء',
      DateTime.wednesday: 'الأربعاء',
      DateTime.thursday: 'الخميس',
      DateTime.friday: 'الجمعة',
    };
    final todayArabic = dayNames[DateTime.now().weekday];
    final idx = _days.indexOf(todayArabic ?? 'السبت');
    _selectedDayIndex = idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final plannerState = ref.watch(plannerProvider);
    final currentDay = _days[_selectedDayIndex];
    final dayBlocks = plannerState.studyBlocks.where((b) => b.day == currentDay).toList();
    final dayLectures = plannerState.lectureSchedule.where((l) => l.day == currentDay).toList();

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.surface,
        elevation: 0,
        title: Text(
          'الخطة الأسبوعية',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tokens.textHigh),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.tune_rounded, color: tokens.brand),
            onPressed: () => context.push('/schedule-setup'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_weekly_plan',
        onPressed: () => context.push('/schedule-setup'),
        backgroundColor: tokens.brand,
        icon: Icon(Icons.add, color: tokens.onBrand),
        label: Text(
          'إضافة لمواعيدي',
          style: TextStyle(fontWeight: FontWeight.bold, color: tokens.onBrand),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Days horizontal selector
            Container(
              height: 56,
              color: tokens.surface,
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
                        color: isSelected
                            ? tokens.brand
                            : tokens.surfaceAlt,
                        borderRadius: AppRadii.fullRadius,
                        border: Border.all(color: tokens.border),
                      ),
                      child: Center(
                        child: Text(
                          _days[index],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? tokens.onBrand
                                : tokens.textMedium,
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
                    child: _buildMiniStatCard('جلسات اليوم', '${dayBlocks.length} جلسات', tokens.brand),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniStatCard('محاضرات رسمية', '${dayLectures.length} محاضرات', tokens.brand),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniStatCard('إنجاز الأسبوع', '${(plannerState.progressPercentage * 100).round()}%', tokens.brand),
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
                      ribbonColor: block.isCompleted ? tokens.success : block.ribbonColor,
                      type: block.isCompleted ? 'مكتملة' : 'جلسة مذاكرة',
                      isInteractive: true,
                      onTap: () => context.push('/study-block-details', extra: block),
                    );
                  }),

                  if (dayLectures.isEmpty && dayBlocks.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                        child: currentDay == 'الجمعة'
                            ? Column(
                                children: [
                                  Icon(Icons.weekend_rounded, size: 48, color: tokens.textLow),
                                  const SizedBox(height: 12),
                                  Text(
                                    'عطلة نهاية الأسبوع • استراحة أسبوعية',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textHigh),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'يوم الجمعة مخصص للراحة وتجديد النشاط والعبادة. لا توجد جلسات مذاكرة أو محاضرات مقررة.',
                                    style: TextStyle(fontSize: 13, color: tokens.textMedium),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  Icon(Icons.calendar_month_outlined, size: 48, color: tokens.textLow),
                                  const SizedBox(height: 12),
                                  Text(
                                    'لا توجد مواعيد مسجلة لهذا اليوم',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tokens.textHigh),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'يمكنك إضافة محاضراتك لتوليد خطة المذاكرة الأسبوعية تلقائياً.',
                                    style: TextStyle(fontSize: 12, color: tokens.textMedium),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 14),
                                  ElevatedButton.icon(
                                    onPressed: () => context.push('/schedule-setup'),
                                    icon: Icon(Icons.add_rounded, size: 18, color: tokens.onBrand),
                                    label: Text('إعداد جدول المحاضرات', style: TextStyle(color: tokens.onBrand, fontSize: 13)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: tokens.brand,
                                      shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
                                    ),
                                  ),
                                ],
                              ),
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
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: AppRadii.controlRadius,
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.textLow)),
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
    VoidCallback? onTap,
  }) {
    final tokens = context.tokens;
    final unifiedAccentColor = tokens.brand;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: AppRadii.controlRadius,
        border: Border.all(color: tokens.border),
      ),
      child: InkWell(
        borderRadius: AppRadii.controlRadius,
        onTap: onTap ?? () {
          context.push('/study-block-details');
        },
        child: ClipRRect(
          borderRadius: AppRadii.controlRadius,
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 4.5, color: unifiedAccentColor.withValues(alpha: 0.7)),
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
                                color: tokens.brandContainer.withValues(alpha: 0.5),
                                borderRadius: AppRadii.controlRadius,
                              ),
                              child: Text(
                                type,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: unifiedAccentColor),
                              ),
                            ),
                            Text(time, style: TextStyle(fontSize: 11, color: tokens.textLow)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: tokens.textHigh,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 13, color: tokens.textLow),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: TextStyle(fontSize: 11, color: tokens.textMedium),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.arrow_back_ios_rounded, size: 12, color: tokens.textLow),
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
