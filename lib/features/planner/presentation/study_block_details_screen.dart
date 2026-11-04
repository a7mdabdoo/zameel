// مطور 3
// فيجما: تفاصيل جلسة المذاكرة - ذاكر وعلّم

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';

class StudyBlockDetailsScreen extends ConsumerStatefulWidget {
  const StudyBlockDetailsScreen({super.key});

  @override
  ConsumerState<StudyBlockDetailsScreen> createState() => _StudyBlockDetailsScreenState();
}

class _StudyBlockDetailsScreenState extends ConsumerState<StudyBlockDetailsScreen> {
  bool _isRunning = false;
  final int _secondsLeft = 45 * 60; // 45 دقيقة

  @override
  Widget build(BuildContext context) {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');

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
          'جلسة مذاكرة مركزة',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Course header card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: const Border(
                    right: BorderSide(color: AppColors.courseSage, width: 6),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.courseSage.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'CS202',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepSage),
                          ),
                        ),
                        Text(
                          'هياكل البيانات (Data Structures)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'الموضوع: الأشجار الثنائية وأشجار البحث المتوازنة (AVL & BST)',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'الموقع: مكتبة الكلية • الطابق الثاني',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Timer Display
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).cardTheme.color,
                    border: Border.all(color: AppColors.primary, width: 6),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$minutes:$seconds',
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isRunning ? 'المؤقت يعمل • ركّز الآن' : 'جلسة 45 دقيقة',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Timer toggle button
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isRunning = !_isRunning;
                    });
                  },
                  icon: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                  label: Text(
                    _isRunning ? 'إيقاف مؤقت' : 'بدء المؤقت',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Action buttons (حسب دليل Stitch والجدول 3)
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // تحديث الحالة في Riverpod
                    ref.read(plannerProvider.notifier).markBlockCompleted('block_1');

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('أحسنت! تم تسجيل إتمام جلسة المذاكرة بنجاح 🎉')),
                    );
                    context.pop();
                  },
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: const Text(
                    'تمت المذاكرة',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref.read(plannerProvider.notifier).rescheduleBlock('block_1');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم تأجيل وإعادة جدولة الجلسة تلقائياً')),
                        );
                        context.pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: const BorderSide(color: AppColors.warning),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('إعادة جدولة', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref.read(plannerProvider.notifier).markBlockMissed('block_1');
                        context.pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('فاتتني الجلسة', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
