// مطور 3
// فيجما: تفاصيل جلسة المذاكرة - مؤقت البومودورو وإدارة الجلسة

import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/app_models.dart';
import '../../../core/state/app_state.dart';
import '../../../core/services/focus_dnd_service.dart';
import '../../auth/data/auth_service.dart';
import '../../timebank/data/timebank_repository.dart';

class StudyBlockDetailsScreen extends ConsumerStatefulWidget {
  final StudyBlockModel? block;

  const StudyBlockDetailsScreen({super.key, this.block});

  @override
  ConsumerState<StudyBlockDetailsScreen> createState() =>
      _StudyBlockDetailsScreenState();
}

class _StudyBlockDetailsScreenState
    extends ConsumerState<StudyBlockDetailsScreen> {
  Timer? _timer;
  bool _isRunning = false;

  // 0 = تركيز | 1 = استراحة قصيرة | 2 = استراحة طويلة
  int _currentMode = 0;

  // الإعدادات المخصصة من الطالب
  int _focusMinutes = 25;
  int _breakMinutes = 5;
  int _longBreakMinutes = 15;
  int _sessionsBeforeLongBreak = 4;
  int _completedSessions = 0;
  bool _pointAwardedInThisScreen = false;

  late int _totalSeconds;
  late int _secondsLeft;

  StudyBlockModel get _block {
    if (widget.block != null) return widget.block!;
    try {
      final blocks = ref.read(plannerProvider).studyBlocks;
      if (blocks.isNotEmpty) return blocks.first;
    } catch (_) {}
    return const StudyBlockModel(
      id: 'block_1',
      courseId: 'CS202',
      courseName: 'هياكل البيانات (Data Structures)',
      courseCode: 'CS202',
      topic: 'الأشجار الثنائية وأشجار البحث المتوازنة (AVL & BST)',
      day: 'السبت',
      startTime: '11:00 ص',
      endTime: '11:45 ص',
      durationMinutes: 45,
      ribbonColor: AppColors.courseSage,
      room: 'مكتبة الكلية • الطابق الثاني',
    );
  }

  @override
  void initState() {
    super.initState();
    final blockDuration = widget.block?.durationMinutes ?? 25;
    _focusMinutes = blockDuration > 0 ? blockDuration : 25;
    _totalSeconds = _focusMinutes * 60;
    _secondsLeft = _totalSeconds;
    _pointAwardedInThisScreen = widget.block?.isCompleted ?? false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    ref.read(focusDndServiceProvider).disableDnd();
    super.dispose();
  }

  void _toggleTimer() {
    if (_isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    if (_currentMode == 0) {
      ref.read(focusDndServiceProvider).enableDnd();
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
        ref.read(focusDndServiceProvider).disableDnd();
        setState(() => _isRunning = false);
        _onSessionComplete();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    ref.read(focusDndServiceProvider).disableDnd();
    setState(() => _isRunning = false);
  }

  void _switchMode(int mode) {
    if (_currentMode == mode) return;
    _timer?.cancel();
    ref.read(focusDndServiceProvider).disableDnd();
    setState(() {
      _currentMode = mode;
      _isRunning = false;
      _totalSeconds = _getDurationForMode(mode);
      _secondsLeft = _totalSeconds;
    });
  }

  int _getDurationForMode(int mode) {
    switch (mode) {
      case 1:
        return _breakMinutes * 60;
      case 2:
        return _longBreakMinutes * 60;
      default:
        return _focusMinutes * 60;
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    ref.read(focusDndServiceProvider).disableDnd();
    setState(() {
      _isRunning = false;
      _secondsLeft = _totalSeconds;
    });
  }

  void _onSessionComplete() {
    if (!mounted) return;
    final block = _block;
    if (_currentMode == 0) {
      setState(() {
        _completedSessions++;
      });

      // حفظ إتمام كتلة المذاكرة (مرة واحدة فقط لكل كتلة مذاكرة)
      final wasAlreadyAwarded = _pointAwardedInThisScreen || block.isCompleted;
      if (!wasAlreadyAwarded) {
        _pointAwardedInThisScreen = true;
        ref.read(plannerProvider.notifier).markBlockCompleted(block.id);
        final uid = ref.read(authServiceProvider).currentUser?.uid;
        if (uid != null && uid.isNotEmpty) {
          ref.read(timeBankRepositoryProvider).awardStudyPoint(
            userId: uid,
            title: 'إتمام جلسة تركيز: ${block.courseName}',
            blockId: block.id,
            points: 1,
          );
          _checkAndAwardDailyDone(uid, block.id);
        }
      }

      final remainingForLongBreak = _sessionsBeforeLongBreak -
          (_completedSessions % _sessionsBeforeLongBreak);
      if (_completedSessions % _sessionsBeforeLongBreak == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D9488),
            duration: const Duration(seconds: 4),
            content: Text(
              !wasAlreadyAwarded
                  ? 'أحسنت في مذاكرة ${block.courseName}! حصلت على +1 نقطة وقت 🪙 وأتممت $_sessionsBeforeLongBreak جلسات تركيز 🎉 حان وقت الاستراحة الطويلة ($_longBreakMinutes دقيقة)!'
                  : 'أحسنت! أتممت $_sessionsBeforeLongBreak جلسات تركيز 🎉 حان وقت الاستراحة الطويلة ($_longBreakMinutes دقيقة)!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
        _switchMode(2); // استراحة طويلة
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
            content: Text(
              !wasAlreadyAwarded
                  ? 'أحسنت! أنهيت جلسة تركيز بنجاح وحصلت على +1 نقطة وقت 🪙🎉 متبقي $remainingForLongBreak جلسات على الاستراحة الكبيرة!'
                  : 'أحسنت! أنهيت جلسة تركيز بنجاح 🎉 متبقي $remainingForLongBreak جلسات على الاستراحة الكبيرة!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
        _switchMode(1); // استراحة قصيرة
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 3),
          content: Text(
            'انتهت الاستراحة! جاهز لجولة تركيز جديدة؟ 🚀',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      _switchMode(0); // عودة للتركيز
    }
  }

  void _showLongBreakInfo(BuildContext context) {
    final cycleIndex = _completedSessions % _sessionsBeforeLongBreak;
    final remainingForLongBreak = _sessionsBeforeLongBreak - cycleIndex;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  const Text(
                    'دورة التركيز والاستراحة الطويلة 🌴',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // تمثيل الجلسات المكتملة
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_sessionsBeforeLongBreak, (index) {
                  final isDone = index < cycleIndex;
                  final isCurrent = index == cycleIndex;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppColors.success.withValues(alpha: 0.15)
                          : (isCurrent
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : AppColors.surfaceAlt),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDone
                            ? AppColors.success
                            : (isCurrent
                                ? AppColors.primary
                                : (Theme.of(ctx).brightness == Brightness.dark
                                    ? AppColors.darkHairline
                                    : AppColors.hairline)),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      isDone ? '✓' : (isCurrent ? '⏳' : '○'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDone
                            ? AppColors.success
                            : (isCurrent
                                ? AppColors.primary
                                : AppColors.textTertiary),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(ctx).brightness == Brightness.dark
                        ? AppColors.darkHairline
                        : AppColors.hairline,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'أنت الآن في الجلسة: رقم ${cycleIndex + 1} من $_sessionsBeforeLongBreak',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      remainingForLongBreak == _sessionsBeforeLongBreak
                          ? 'متبقي لك $_sessionsBeforeLongBreak جلسات تركيز للحصول على الاستراحة الطويلة ($_longBreakMinutes دقيقة)!'
                          : 'متبقي لك $remainingForLongBreak جلسات تركيز فقط للحصول على الاستراحة الطويلة ($_longBreakMinutes دقيقة)!',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'إجمالي جلسات التركيز المكتملة: $_completedSessions جلسات',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _switchMode(2); // التبديل إلى استراحة طويلة
                },
                icon: const Icon(Icons.coffee_rounded,
                    color: Colors.white, size: 18),
                label: Text(
                  'أخذ استراحة طويلة الآن ($_longBreakMinutes دقيقة) 🌴',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSettingsSheet(BuildContext context) {
    int tempFocus = _focusMinutes;
    int tempBreak = _breakMinutes;
    int tempLongBreak = _longBreakMinutes;
    int tempSessions = _sessionsBeforeLongBreak;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      const Text(
                        'تحديد مدة المذاكرة والاستراحة ⏱️',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1. مدة المذاكرة
                  const Text('مدة المذاكرة والتركيز:',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [15, 20, 25, 30, 45, 60].map((m) {
                      final isSelected = tempFocus == m;
                      return ChoiceChip(
                        label: Text('$m دقيقة'),
                        selected: isSelected,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) =>
                            setModalState(() => tempFocus = m),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // 2. مدة الاستراحة القصيرة
                  const Text('مدة الاستراحة القصيرة:',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [3, 5, 10, 15].map((m) {
                      final isSelected = tempBreak == m;
                      return ChoiceChip(
                        label: Text('$m دقائق'),
                        selected: isSelected,
                        selectedColor:
                            const Color(0xFFD97706).withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? const Color(0xFFD97706)
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) =>
                            setModalState(() => tempBreak = m),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // 3. استراحة طويلة كل كم جلسة
                  const Text('أخذ استراحة طويلة بعد كل:',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [2, 3, 4, 5].map((s) {
                      final isSelected = tempSessions == s;
                      return ChoiceChip(
                        label: Text('$s جلسات'),
                        selected: isSelected,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) =>
                            setModalState(() => tempSessions = s),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // 4. مدة الاستراحة الطويلة
                  const Text('مدة الاستراحة الطويلة:',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [15, 20, 25, 30].map((m) {
                      final isSelected = tempLongBreak == m;
                      return ChoiceChip(
                        label: Text('$m دقيقة'),
                        selected: isSelected,
                        selectedColor:
                            const Color(0xFF0D9488).withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? const Color(0xFF0D9488)
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) =>
                            setModalState(() => tempLongBreak = m),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _timer?.cancel();
                      setState(() {
                        _isRunning = false;
                        _focusMinutes = tempFocus;
                        _breakMinutes = tempBreak;
                        _longBreakMinutes = tempLongBreak;
                        _sessionsBeforeLongBreak = tempSessions;
                        _totalSeconds = _getDurationForMode(_currentMode);
                        _secondsLeft = _totalSeconds;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'تم حفظ وتطبيق أوقات الجلسات الجديدة بنجاح ⏱️'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('حفظ الإعدادات وتطبيقها',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _checkAndAwardDailyDone(String uid, String completedBlockId) {
    final now = DateTime.now();
    const dayNames = {
      DateTime.saturday: 'السبت',
      DateTime.sunday: 'الأحد',
      DateTime.monday: 'الاثنين',
      DateTime.tuesday: 'الثلاثاء',
      DateTime.wednesday: 'الأربعاء',
      DateTime.thursday: 'الخميس',
      DateTime.friday: 'الجمعة',
    };
    final todayArabic = dayNames[now.weekday] ?? 'السبت';
    final planner = ref.read(plannerProvider);
    final todayBlocks = planner.studyBlocks.where((b) => b.day == todayArabic).toList();
    final remaining = todayBlocks.where((b) => !b.isCompleted && b.id != completedBlockId).length;
    if (remaining == 0 && todayBlocks.isNotEmpty) {
      final todayKey = 'daily_done_${now.year}_${now.month}_${now.day}';
      ref.read(timeBankRepositoryProvider).awardStudyPoint(
        userId: uid,
        title: 'مكافأة إتمام جميع مهام اليوم',
        blockId: todayKey,
        points: 1,
      );
    }
  }

  void _markCompleted() {
    final block = _block;
    final wasAlreadyAwarded = _pointAwardedInThisScreen || block.isCompleted;
    if (wasAlreadyAwarded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنجاز هذه المهمة بالفعل ولا يمكن التراجع عنها ✓'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.pop();
      }
      return;
    }

    ref.read(plannerProvider.notifier).markBlockCompleted(block.id);
    _pointAwardedInThisScreen = true;

    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      ref.read(timeBankRepositoryProvider).awardStudyPoint(
        userId: uid,
        title: 'إتمام مذاكرة: ${block.courseName}',
        blockId: block.id,
        points: 1,
      );
      _checkAndAwardDailyDone(uid, block.id);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('أحسنت! تم تسجيل إتمام مذاكرة "${block.courseName}" بنجاح 🎉'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = _block;
    final isAlreadyCompleted = _pointAwardedInThisScreen || block.isCompleted;
    final progress = _totalSeconds > 0
        ? (1.0 - (_secondsLeft / _totalSeconds)).clamp(0.0, 1.0)
        : 0.0;
    final activeColor = _currentMode == 0
        ? AppColors.primary
        : (_currentMode == 1
            ? const Color(0xFFD97706)
            : const Color(0xFF0D9488));

    final cycleIndex = _completedSessions % _sessionsBeforeLongBreak;
    final remainingForLongBreak = _sessionsBeforeLongBreak - cycleIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hairline = isDark ? AppColors.darkHairline : AppColors.hairline;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('جلسة مذاكرة مركزة'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // ── بطاقة تفاصيل المادة ──────────────────────────────
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: block.ribbonColor, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: block.ribbonColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          block.courseCode.isNotEmpty ? block.courseCode : 'مادة',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: block.ribbonColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          block.courseName,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'الموضوع: ${block.topic}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'الموقع: ${block.room} • الموعد: ${block.startTime}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── كارت مؤقت البومودورو ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isRunning
                    ? activeColor.withValues(alpha: 0.5)
                    : hairline,
                width: _isRunning ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isRunning
                      ? activeColor.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. الشريط العلوي: الحالة وزر تخصيص الأوقات
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _currentMode == 0
                                ? Icons.timer_outlined
                                : (_currentMode == 1
                                    ? Icons.coffee_rounded
                                    : Icons.wb_sunny_outlined),
                            size: 18,
                            color: activeColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, size: 19),
                          tooltip: 'تخصيص مدة المذاكرة والاستراحة',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surfaceAlt,
                            padding: const EdgeInsets.all(8),
                          ),
                          onPressed: () => _showSettingsSheet(context),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          _currentMode == 0
                              ? 'جلسة تركيز'
                              : (_currentMode == 1
                                  ? 'استراحة قصيرة'
                                  : 'استراحة طويلة'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: (_isRunning ? activeColor : AppColors.sage)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _isRunning
                                      ? activeColor
                                      : AppColors.deepSage,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isRunning ? 'يعمل الآن' : 'جاهز للبدء',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _isRunning
                                      ? activeColor
                                      : AppColors.deepSage,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 2. المؤقت الدائري الكبير
                Center(
                  child: SizedBox(
                    width: 170,
                    height: 170,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 170,
                          height: 170,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 8,
                            backgroundColor: AppColors.surfaceAlt,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(activeColor),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatTime(_secondsLeft),
                              style: TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.bold,
                                color: activeColor,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isRunning
                                  ? 'المؤقت يعمل • ركّز الآن'
                                  : (_currentMode == 0
                                      ? 'جلسة $_focusMinutes دقيقة'
                                      : (_currentMode == 1
                                          ? 'استراحة $_breakMinutes دقيقة'
                                          : 'بريك كبير $_longBreakMinutes دقيقة')),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                if (_isRunning && _currentMode == 0) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final hasPerm = await ref.read(focusDndServiceProvider).hasPermission();
                        if (!context.mounted) return;
                        if (!hasPerm) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('وضع عدم الإزعاج (DND)'),
                              content: const Text(
                                'لتفعيل الصامت التلقائي وكتم الإشعارات الخارجية على هاتفك أثناء جلسات التركيز، يرجى منح إذن الوصول للإشعارات، أو تفعيل نمط عدم الإزعاج يدوياً من مركز التحكم.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('لاحقاً'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    ref.read(focusDndServiceProvider).openDndSettings();
                                  },
                                  child: const Text('فتح الإعدادات'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.do_not_disturb_on_rounded, size: 14, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'وضع التركيز وعدم الإزعاج نشط 🔕',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // 3. أزرار التبديل السريع بين الأوضاع
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _switchMode(0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _currentMode == 0
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _currentMode == 0
                                  ? AppColors.primary
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'تركيز ($_focusMinutes د)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _currentMode == 0
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _switchMode(1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _currentMode == 1
                                ? const Color(0xFFD97706).withValues(alpha: 0.12)
                                : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _currentMode == 1
                                  ? const Color(0xFFD97706)
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'استراحة ($_breakMinutes د)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _currentMode == 1
                                    ? const Color(0xFFD97706)
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _switchMode(2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _currentMode == 2
                                ? const Color(0xFF0D9488).withValues(alpha: 0.12)
                                : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _currentMode == 2
                                  ? const Color(0xFF0D9488)
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'بريك كبير ($_longBreakMinutes د)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _currentMode == 2
                                    ? const Color(0xFF0D9488)
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 4. أزرار التحكم (بدء / إيقاف، إعادة ضبط، السهم لمعرفة موعد البريك الكبير)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: _toggleTimer,
                        icon: Icon(
                          _isRunning
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: Text(
                          _isRunning
                              ? 'إيقاف مؤقت'
                              : (_currentMode == 0
                                  ? 'ابدأ التركيز الآن'
                                  : 'بدء الاستراحة الآن'),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    if (_secondsLeft < _totalSeconds) ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _resetTimer,
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        tooltip: 'إعادة ضبط المؤقت',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceAlt,
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => _showLongBreakInfo(context),
                      icon: const Icon(Icons.beach_access_rounded,
                          size: 20, color: Color(0xFF0D9488)),
                      tooltip: 'كم جلسة متبقية للاستراحة الطويلة؟ 🌴',
                      style: IconButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF0D9488).withValues(alpha: 0.12),
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // شريط توضيح دورة البريك الكبير
                InkWell(
                  onTap: () => _showLongBreakInfo(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              const Color(0xFF0D9488).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 12, color: Color(0xFF0D9488)),
                        Row(
                          children: [
                            Text(
                              'الجلسة ${cycleIndex + 1} من $_sessionsBeforeLongBreak • استراحة كبيرة بعد $remainingForLongBreak جلسات',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D9488)),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.beach_access_rounded,
                                size: 14, color: Color(0xFF0D9488)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── زر تمت المذاكرة ──────────────────────────
          FilledButton.icon(
            onPressed: isAlreadyCompleted ? null : _markCompleted,
            icon: Icon(isAlreadyCompleted ? Icons.check_circle : Icons.check_circle_outline),
            label: Text(
              isAlreadyCompleted ? 'تمت المذاكرة بنجاح ✓' : 'تمت المذاكرة',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              disabledBackgroundColor: AppColors.success.withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),

          const SizedBox(height: 12),

          // ── أزرار إعادة الجدولة وفاتتني ─────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isAlreadyCompleted
                      ? null
                      : () {
                          ref.read(plannerProvider.notifier).rescheduleBlock(block.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم تأجيل وإعادة جدولة جلسة "${block.courseName}" تلقائياً'),
                              ),
                            );
                            context.pop();
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: BorderSide(
                      color: isAlreadyCompleted ? hairline : AppColors.warning,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('إعادة جدولة',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: isAlreadyCompleted
                      ? null
                      : () {
                          ref.read(plannerProvider.notifier).markBlockMissed(block.id);
                          if (mounted) context.pop();
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: isAlreadyCompleted ? hairline : AppColors.error,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('فاتتني الجلسة',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
