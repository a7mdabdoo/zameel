// مطور 3
// فيجما: بنك الوقت: طلب مساعدة

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

class NeedHelpScreen extends StatefulWidget {
  const NeedHelpScreen({super.key});

  @override
  State<NeedHelpScreen> createState() => _NeedHelpScreenState();
}

class _NeedHelpScreenState extends State<NeedHelpScreen> {
  CourseSeed _selectedCourse = AppConstants.seedCourses[3]; // الجبر الخطي
  final _topicController = TextEditingController(text: 'الفضاءات المتجهة والتحويلات الخطية');
  final String _preferredSlot = 'اليوم بعد الظهر (بين 1:00 م و 3:00 م)';

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

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
          'طلب مساعدة من زميل 🤝',
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
              // Info Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'جلسة الشرح تكلف 1 عملة وقت فقط. بعد انتهاء الجلسة يتم تحويلها للزميل الشارح تلقائياً.',
                        style: TextStyle(fontSize: 12, color: AppColors.primary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Course
              const Text('المادة التي تحتاج مساعدة فيها', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
                            Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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

              const SizedBox(height: 20),

              // Topic description
              const Text('ما الجزء أو الموضوع المحدد؟', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _topicController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'اكتب ما تواجه صعوبة فيه (مثال: التحويلات الخطية والمصفوفات)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.hairline)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.hairline)),
                ),
              ),

              const SizedBox(height: 20),

              // Preferred time
              const Text('الوقت المفضل لك', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_preferredSlot, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Search CTA -> /candidates
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/candidates'),
                  icon: const Icon(Icons.search_rounded, color: Colors.white),
                  label: const Text(
                    'ابحث عن زميل متاح',
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
