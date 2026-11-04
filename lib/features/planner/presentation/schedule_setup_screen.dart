// مطور 3
// فيجما: إعداد الجدول - ذاكر وعلّم

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

class ScheduleSetupScreen extends StatefulWidget {
  const ScheduleSetupScreen({super.key});

  @override
  State<ScheduleSetupScreen> createState() => _ScheduleSetupScreenState();
}

class _ScheduleSetupScreenState extends State<ScheduleSetupScreen> {
  String _selectedDay = 'السبت';
  CourseSeed _selectedCourse = AppConstants.seedCourses[0];
  String _room = 'قاعة 3';
  double _maxDailyHours = 3.0;

  final List<String> _days = ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'إعداد وتخصيص الجدول ⚙️',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'إضافة محاضرة أو وقت انشغال',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'تساعد هذه المواعيد الخوارزمية في تحديد أوقات الفراغ المناسبة للمذاكرة وبنك الوقت',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),

              // Day selector
              const Text('اليوم', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDay,
                    isExpanded: true,
                    items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDay = val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Course selector
              const Text('المادة الدراسية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<CourseSeed>(
                    value: _selectedCourse,
                    isExpanded: true,
                    items: AppConstants.seedCourses.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(c.name, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCourse = val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Room / Location
              const Text('المكان / القاعة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _room,
                onChanged: (val) => _room = val,
                decoration: InputDecoration(
                  hintText: 'قاعة 3 أو معمل الحاسب',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.hairline)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.hairline)),
                ),
              ),

              const SizedBox(height: 20),

              // Daily study hours slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_maxDailyHours.toInt()} ساعات', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const Text('الحد الأقصى للمذاكرة اليومية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
              Slider(
                value: _maxDailyHours,
                min: 1.0,
                max: 6.0,
                divisions: 5,
                activeColor: AppColors.primary,
                onChanged: (val) => setState(() => _maxDailyHours = val),
              ),

              const SizedBox(height: 32),

              // Save button -> pop back
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حفظ الموعد وتحديث الخطة الذكية بنجاح ✅')),
                    );
                    context.pop();
                  },
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text(
                    'حفظ المحاضرة والجدول',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
