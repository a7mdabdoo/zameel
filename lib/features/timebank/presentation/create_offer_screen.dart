// مطور 3
// فيجما: إضافة عرض جديد - ذاكر وعلّم

import 'package:flutter/material.dart';
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
  final _meetingLinkController = TextEditingController();
  String _selectedDay = 'الأحد';
  String _selectedTime = '12:00 ظهراً';
  bool _isOnline = false;
  bool _isPublishing = false;

  final List<String> _days = ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
  final List<String> _times = ['10:00 صباحاً', '11:00 صباحاً', '12:00 ظهراً', '01:00 ظهراً', '02:00 مساءً', '03:00 مساءً', '04:00 مساءً', '05:00 مساءً'];

  @override
  void dispose() {
    _topicController.dispose();
    _offlineLocationController.dispose();
    _meetingLinkController.dispose();
    super.dispose();
  }

  Future<void> _publishOffer() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة الموضوع الذي ستشرحه لزملائك')),
      );
      return;
    }

    String finalLocation = '';
    if (_isOnline) {
      final link = _meetingLinkController.text.trim();
      if (link.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إدخال رابط الاجتماع (Google Meet أو Zoom)')),
        );
        return;
      }
      finalLocation = 'أونلاين: $link';
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
      final newOffer = TimeBankOfferModel(
        id: offerId,
        teacherId: user.uid,
        teacherName: profileName,
        courseId: _selectedCourse.id,
        courseName: _selectedCourse.name,
        courseCode: _selectedCourse.code,
        topic: topic,
        day: _selectedDay,
        time: _selectedTime,
        durationMinutes: 60,
        location: finalLocation,
        courseColor: _selectedCourse.color,
        isAvailable: true,
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

              // Day & Time Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('اليوم المناسب', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الوقت المناسب', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedTime,
                              isExpanded: true,
                              items: _times.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedTime = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                Text('رابط الاجتماع (Zoom أو Google Meet)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _meetingLinkController,
                  decoration: InputDecoration(
                    hintText: 'https://meet.google.com/xyz-abcd-efg أو رابط Zoom',
                    prefixIcon: const Icon(Icons.link_rounded, size: 20, color: AppColors.primary),
                    filled: true,
                    fillColor: Theme.of(context).cardTheme.color,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.hairline)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.hairline)),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '💡 سيظهر هذا الرابط لزميلك عند حجز الجلسة ليتمكن من الانضمام إليك بسهولة.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
