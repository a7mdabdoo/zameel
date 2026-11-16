// مطور 3
// فيجما: إضافة عرض جديد - ذاكر وعلّم

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/app_models.dart';
import '../../../core/state/app_state.dart';

import '../../../features/auth/data/auth_service.dart';
import '../../../features/timebank/data/timebank_repository.dart';

class CreateOfferScreen extends ConsumerStatefulWidget {
  const CreateOfferScreen({super.key});

  @override
  ConsumerState<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends ConsumerState<CreateOfferScreen> {
  CourseSeed _selectedCourse = AppConstants.seedCourses[0]; // OOP
  final _topicController = TextEditingController();
  final _offlineLocationController = TextEditingController(text: 'مكتبة الكلية • قاعة الاستذكار 2');
  bool _isOnline = false;
  bool _isPublishing = false;

  // فترات الإتاحة الأسبوعية (Africa/Cairo)
  final List<OfferTimeSlot> _slots = [
    const OfferTimeSlot(weekday: 1, startMin: 600, endMin: 720), // الأحد 10:00 ص - 12:00 م
  ];

  int _pickerWeekday = 1; // الأحد
  int _pickerStartMin = 600; // 10:00 ص
  int _pickerEndMin = 720;   // 12:00 م

  static final List<int> _availableMinutes = [
    for (int m = 480; m <= 1260; m += 30) m, // من 08:00 إلى 21:00
  ];

  @override
  void dispose() {
    _topicController.dispose();
    _offlineLocationController.dispose();
    super.dispose();
  }

  void _addSlot() {
    if (_pickerEndMin <= _pickerStartMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('وقت نهاية الفترة يجب أن يكون بعد وقت البداية')),
      );
      return;
    }
    if (_pickerEndMin - _pickerStartMin < 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أقل مدة لفترة الإتاحة هي 30 دقيقة')),
      );
      return;
    }

    final exists = _slots.any((s) =>
        s.weekday == _pickerWeekday &&
        s.startMin == _pickerStartMin &&
        s.endMin == _pickerEndMin);

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذه الفترة مضافة بالفعل')),
      );
      return;
    }

    setState(() {
      _slots.add(OfferTimeSlot(
        weekday: _pickerWeekday,
        startMin: _pickerStartMin,
        endMin: _pickerEndMin,
      ));
    });
  }

  void _removeSlot(int index) {
    if (_slots.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب الإبقاء على فترة إتاحة واحدة على الأقل')),
      );
      return;
    }
    setState(() {
      _slots.removeAt(index);
    });
  }

  Future<void> _publishOffer() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة الموضوع الذي ستشرحه لزملائك')),
      );
      return;
    }

    if (_slots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد فترة إتاحة أسبوعية واحدة على الأقل للشرح')),
      );
      return;
    }

    String finalLocation = '';
    if (_isOnline) {
      finalLocation = 'عبر الإنترنت (أونلاين)';
    } else {
      final place = _offlineLocationController.text.trim();
      if (place.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى كتابة مكان المقابلة في الكلية')),
        );
        return;
      }
      finalLocation = place;
    }

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
      );
      return;
    }

    if (!user.emailVerified) {
      final nowVerified = await ref.read(authServiceProvider).reloadUserAndCheckVerified();
      if (!nowVerified) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('يجب تأكيد بريدك الإلكتروني أولاً لنشر عروض الشرح'),
              action: SnackBarAction(
                label: 'أنا أكدت بريدي',
                textColor: Colors.amber,
                onPressed: () async {
                  final v = await ref.read(authServiceProvider).reloadUserAndCheckVerified();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(v ? 'تم التحقق من بريدك بنجاح! يمكنك الآن النشر 🎉' : 'لم يتم التأكيد بعد، يرجى مراجعة بريدك 📩')),
                    );
                  }
                },
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        }
        return;
      }
    }

    setState(() => _isPublishing = true);

    try {
      final profileAsync = ref.read(userProfileStreamProvider);
      final profileName = profileAsync.value?.data()?['name'] as String? ?? user.displayName ?? 'زميل';

      final offerId = 'offer_${DateTime.now().millisecondsSinceEpoch}_${user.uid.substring(0, 5)}';
      final daySummary = _slots.map((s) => s.weekdayName).toSet().join('، ');
      final timeSummary = _slots.map((s) => '${OfferTimeSlot.formatMinutes(s.startMin)} – ${OfferTimeSlot.formatMinutes(s.endMin)}').join(' | ');

      final newOffer = TimeBankOfferModel(
        id: offerId,
        teacherId: user.uid,
        teacherName: profileName,
        courseId: _selectedCourse.id,
        courseName: _selectedCourse.name,
        courseCode: _selectedCourse.code,
        topic: topic,
        day: daySummary,
        time: timeSummary,
        durationMinutes: 60,
        mode: _isOnline ? 'online' : 'in_person',
        location: finalLocation,
        courseColor: _selectedCourse.color,
        isAvailable: true,
        slots: _slots,
        createdAt: DateTime.now(),
      );

      await ref.read(timeBankRepositoryProvider).createOffer(newOffer);
      ref.read(timeBankProvider.notifier).addOffer(newOffer);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نشر عرض الشرح بنجاح! سيظهر لزملائك فوراً 🎉')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء نشر العرض: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final userDoc = userProfileAsync.value?.data();
    final customCoursesData = (userDoc?['coursesData'] as List<dynamic>?)
        ?.map((m) => CourseSeed.fromMap(Map<String, dynamic>.from(m)))
        .toList() ?? [];

    final availableCourses = customCoursesData.isNotEmpty ? customCoursesData : AppConstants.seedCourses;
    if (!availableCourses.any((c) => c.id == _selectedCourse.id)) {
      _selectedCourse = availableCourses.first;
    }
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
          'أضف عرض شرح جديد 💡',
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
              Text(
                'علّم زميلك واكسب عملات وقت',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 4),
              const Text(
                'كل جلسة شرح مدتها 60 دقيقة تمنحك 1 عملة وقت في محفظتك لاستخدامها في تعلّم مواد أخرى.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),

              // Course
              Text('المادة التي ستقوم بشرحها', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<CourseSeed>(
                    value: availableCourses.contains(_selectedCourse) ? _selectedCourse : availableCourses.first,
                    isExpanded: true,
                    items: availableCourses.map((c) {
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

              // Topic
              Text('ما الموضوع أو الشابتر الذي ستشرحه؟', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _topicController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'مثال: شرح الـ Polymorphism وحل شيت المعمل',
                  filled: true,
                  fillColor: Theme.of(context).cardTheme.color,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.hairline)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.hairline)),
                ),
              ),

              const SizedBox(height: 20),

              // فترات الإتاحة الأسبوعية للشرح (Africa/Cairo)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'فترات الإتاحة الأسبوعية (Africa/Cairo) ⏰',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${_slots.length} فترات محددة',
                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // قائمة الفترات الحالية
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  children: [
                    ..._slots.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final slot = entry.value;
                      return Container(
                        margin: EdgeInsets.only(bottom: idx == _slots.length - 1 ? 0 : 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                slot.formattedRange,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (_slots.length > 1)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _removeSlot(idx),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // صندوق إضافة فترة جديدة
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إضافة فترة إتاحة أخرى:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // اليوم
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.hairline),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _pickerWeekday,
                                isExpanded: true,
                                items: OfferTimeSlot.appWeekdayNames.entries.map((e) {
                                  return DropdownMenuItem<int>(
                                    value: e.key,
                                    child: Text(e.value, style: const TextStyle(fontSize: 12)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _pickerWeekday = val);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // من
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.hairline),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _pickerStartMin,
                                isExpanded: true,
                                items: _availableMinutes.where((m) => m < 1260).map((m) {
                                  return DropdownMenuItem<int>(
                                    value: m,
                                    child: Text('من ${OfferTimeSlot.formatMinutes(m)}', style: const TextStyle(fontSize: 10)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _pickerStartMin = val);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // إلى
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.hairline),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _pickerEndMin,
                                isExpanded: true,
                                items: _availableMinutes.where((m) => m > _pickerStartMin).map((m) {
                                  return DropdownMenuItem<int>(
                                    value: m,
                                    child: Text('إلى ${OfferTimeSlot.formatMinutes(m)}', style: const TextStyle(fontSize: 10)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _pickerEndMin = val);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // زر الإضافة
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add, color: Colors.white, size: 20),
                          onPressed: _addSlot,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Meeting Mode: Offline vs Online
              Text('طريقة اللقاء والشرح', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isOnline = false),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isOnline ? AppColors.primary.withValues(alpha: 0.12) : Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: !_isOnline ? AppColors.primary : AppColors.hairline,
                            width: !_isOnline ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_outlined, size: 18, color: !_isOnline ? AppColors.primary : AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              'حضوري بالكلية 🏛️',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: !_isOnline ? AppColors.primary : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isOnline = true),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isOnline ? AppColors.primary.withValues(alpha: 0.12) : Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isOnline ? AppColors.primary : AppColors.hairline,
                            width: _isOnline ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_outlined, size: 18, color: _isOnline ? AppColors.primary : AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              'أونلاين عن بُعد 💻',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _isOnline ? AppColors.primary : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (!_isOnline) ...[
                Text('مكان المقابلة المقترح في الكلية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _offlineLocationController,
                  decoration: InputDecoration(
                    hintText: 'مثال: مكتبة الكلية • قاعة الاستذكار 2',
                    prefixIcon: const Icon(Icons.place_outlined, size: 20, color: AppColors.primary),
                    filled: true,
                    fillColor: Theme.of(context).cardTheme.color,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.hairline)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.hairline)),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'حفاظاً على خصوصيتك، ستتمكن من إضافة رابط اللقاء (Zoom / Google Meet) داخل تفاصيل الجلسة بعد تأكيد الحجز من زميلك.',
                          style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 36),

              // Submit CTA -> /my-offers
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isPublishing ? null : _publishOffer,
                  icon: _isPublishing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check, color: Colors.white),
                  label: Text(
                    _isPublishing ? 'جاري نشر العرض...' : 'نشر العرض في بنك الوقت',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
