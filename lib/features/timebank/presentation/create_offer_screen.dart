// مطور 3
// بنك الوقت: إنشاء ونشر عرض شرح أونلاين جديد (Create Online Live Session Offer)

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/auth/data/auth_service.dart';
import '../../../features/timebank/application/timebank_pure_logic.dart';
import '../../../features/timebank/data/timebank_repository.dart';

class CreateOfferScreen extends ConsumerStatefulWidget {
  const CreateOfferScreen({super.key});

  @override
  ConsumerState<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends ConsumerState<CreateOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // 1. المادة والموضوع
  CourseSeed _selectedCourse = AppConstants.seedCourses[0];
  final _topicController = TextEditingController();

  // 2. نوع الجلسة والسعة
  SessionType _sessionType = SessionType.individual;
  int _maxAttendees = 1; // 1 للفردي، 10/25/50/100 للجماعي

  // 3. الموعد الدقيق والمدة
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 20, minute: 0); // 08:00 م
  int _durationMinutes = 60; // 45 أو 60 دقيقة

  // 4. رابط الاجتماع الأونلاين
  final _meetingUrlController = TextEditingController();

  bool _isPublishing = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _topicController.dispose();
    _meetingUrlController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      helpText: 'اختر يوم الجلسة',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      helpText: 'اختر وقت بدء الجلسة',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _publishOffer() async {
    if (!_formKey.currentState!.validate()) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء موضوع الشرح والتأكد من صحة البيانات.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final topic = _topicController.text.trim();
    final rawMeetingUrl = _meetingUrlController.text.trim();
    String? meetingUrl;
    if (rawMeetingUrl.isNotEmpty) {
      meetingUrl = rawMeetingUrl;
      if (!meetingUrl.startsWith('http://') && !meetingUrl.startsWith('https://')) {
        meetingUrl = 'https://$meetingUrl';
      }
    }

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
      );
      return;
    }

    // التحقق من أن الموعد في المستقبل
    final scheduledAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (scheduledAt.isBefore(DateTime.now().add(const Duration(minutes: 10)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار موعد في المستقبل (بعد 15 دقيقة على الأقل)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final userProfileAsync = ref.read(userProfileStreamProvider);
      final userDoc = userProfileAsync.value?.data();
      final teacherName = (userDoc?['name'] as String?)?.isNotEmpty == true
          ? (userDoc!['name'] as String)
          : (user.displayName ?? 'زميل');

      final rawYear = userDoc?['academicYear'];
      String? academicYear;
      if (rawYear is int) {
        academicYear = CurriculumConstants.academicYearLabels[rawYear];
      } else if (rawYear is String) {
        academicYear = rawYear;
      }

      final offerId = 'offer_${DateTime.now().millisecondsSinceEpoch}';

      final offer = TimeBankOfferModel(
        id: offerId,
        teacherId: user.uid,
        teacherName: teacherName,
        teacherRating: ((userDoc?['ratingCount'] as num?)?.toInt() ?? 0) > 0
            ? (((userDoc!['ratingSum'] as num?)?.toDouble() ?? 0.0) / (userDoc['ratingCount'] as num).toDouble())
            : 0.0,
        courseId: _selectedCourse.id,
        courseName: _selectedCourse.name,
        courseCode: _selectedCourse.id.toUpperCase(),
        topic: topic,
        academicYear: academicYear,
        sessionType: _sessionType,
        scheduledAt: scheduledAt,
        durationMinutes: _durationMinutes,
        meetingUrl: meetingUrl,
        maxAttendees: _sessionType == SessionType.individual ? 1 : _maxAttendees,
        attendeeIds: const [],
        isCompleted: false,
        createdAt: DateTime.now(),
        mode: 'online',
        location: 'أونلاين (Google Meet / Zoom)',
        courseColor: _selectedCourse.color,
      );

      await ref.read(timeBankRepositoryProvider).createOffer(offer);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نشر جلسة الشرح بنجاح.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر نشر العرض: $e'),
            backgroundColor: AppColors.error,
          ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final surfaceColor = theme.cardTheme.color ?? (isDark ? const Color(0xFF1E293B) : Colors.white);
    final hairlineColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

    // قائمة المواد
    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final userDoc = userProfileAsync.value?.data();
    final rawCourses = userDoc?['selectedCourses'] as List<dynamic>? ?? [];

    List<CourseSeed> availableCourses = AppConstants.seedCourses;
    if (rawCourses.isNotEmpty) {
      final userMapped = <CourseSeed>[];
      for (final rc in rawCourses) {
        if (rc is Map) {
          userMapped.add(CourseSeed(
            id: rc['id'] as String? ?? 'c_${DateTime.now().millisecondsSinceEpoch}',
            name: rc['name'] as String? ?? 'مقرر دراسي',
            code: rc['code'] as String? ?? 'CS',
            color: rc['color'] != null ? Color((rc['color'] as num).toInt()) : primaryColor,
          ));
        }
      }
      if (userMapped.isNotEmpty) availableCourses = userMapped;
    }

    final scheduledDateFormatted =
        '${TimeBankOfferModel.formatDayArabic(_selectedDate)} ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
    final scheduledTimeFormatted =
        '${_selectedTime.hourOfPeriod == 0 ? 12 : _selectedTime.hourOfPeriod}:${_selectedTime.minute.toString().padLeft(2, '0')} ${_selectedTime.period == DayPeriod.am ? 'صباحاً' : 'مساءً'}';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        title: const Text(
          'إنشاء جلسة شرح جديدة',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // لافتة تعريفية
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: primaryColor, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'جلسات بنك الوقت أونلاين 100%. حدد الموعد ورابط الاجتماع لتمكين زملائك من الانضمام والاستفادة من خبرتك.',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ==========================================
              // الخطوة 1: المادة والموضوع
              // ==========================================
              _buildSectionCard(
                title: '1. المادة وموضوع الشرح',
                surfaceColor: surfaceColor,
                hairlineColor: hairlineColor,
                children: [
                  const Text('المادة المراد شرحها:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<CourseSeed>(
                    initialValue: availableCourses.contains(_selectedCourse) ? _selectedCourse : availableCourses.first,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: hairlineColor),
                      ),
                    ),
                    items: availableCourses.map((c) {
                      return DropdownMenuItem<CourseSeed>(
                        value: c,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCourse = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('عنوان الموضوع والنقاط الرئيسية:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _topicController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'مثال: مراجعة شاملة للـ Polymorphism والـ Interfaces وحل شيت المحاضرة',
                      hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : AppColors.textTertiary),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: hairlineColor),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى كتابة عنوان أو فكرة الشرح';
                      }
                      return null;
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ==========================================
              // الخطوة 2: نوع الجلسة (فردية vs جماعية)
              // ==========================================
              _buildSectionCard(
                title: '2. نوع الجلسة وسعة الحضور',
                surfaceColor: surfaceColor,
                hairlineColor: hairlineColor,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSessionTypeRadio(
                          type: SessionType.individual,
                          title: 'جلسة خاصة (1-on-1)',
                          subtitle: 'شرح مركز لزميل واحد فقط',
                          icon: Icons.person_rounded,
                          primaryColor: primaryColor,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSessionTypeRadio(
                          type: SessionType.group,
                          title: 'جلسة جماعية (Webinar)',
                          subtitle: 'ورشة مفتوحة لعدة طلاب',
                          icon: Icons.groups_rounded,
                          primaryColor: primaryColor,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  if (_sessionType == SessionType.group) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الحد الأقصى لعدد المشاركين:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        Text('$_maxAttendees زميل', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Slider(
                      value: _maxAttendees.toDouble(),
                      min: 2,
                      max: 100,
                      divisions: 98,
                      label: '$_maxAttendees',
                      activeColor: primaryColor,
                      onChanged: (v) => setState(() => _maxAttendees = v.toInt()),
                    ),
                    Center(
                      child: Text(
                        'المكافأة المتوقعة: ${TimeBankPureLogic.calculateTeacherReward(type: _sessionType, attendeeCount: _maxAttendees)} عملات وقت',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.pointsAmber),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // ==========================================
              // الخطوة 3: الموعد الدقيق والمدة
              // ==========================================
              _buildSectionCard(
                title: '3. الموعد المحدد والمدة',
                surfaceColor: surfaceColor,
                hairlineColor: hairlineColor,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _selectDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: hairlineColor),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 16, color: primaryColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    scheduledDateFormatted,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: _selectTime,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: hairlineColor),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 16, color: primaryColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    scheduledTimeFormatted,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('مدة الجلسة:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildDurationChoice(45, primaryColor, isDark),
                      const SizedBox(width: 10),
                      _buildDurationChoice(60, primaryColor, isDark),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ==========================================
              // الخطوة 4: رابط الاجتماع الأونلاين
              // ==========================================
              _buildSectionCard(
                title: '4. رابط الاجتماع (Google Meet / Zoom)',
                surfaceColor: surfaceColor,
                hairlineColor: hairlineColor,
                children: [
                  TextFormField(
                    controller: _meetingUrlController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.link_rounded),
                      hintText: 'https://meet.google.com/xxx-yyyy-zzz',
                      hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : AppColors.textTertiary),
                      helperText: 'اختياري - يمكنك تركه فارغاً وتعيينه أو مشاركته لاحقاً داخل تفاصيل الجلسة',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: hairlineColor),
                      ),
                    ),
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        final v = val.trim();
                        if (!v.contains('.') || v.length < 4) {
                          return 'يرجى إدخال رابط اجتماع صالح أو تركه فارغاً';
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // زر النشر في بنك الوقت
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isPublishing ? null : _publishOffer,
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isPublishing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.rocket_launch_rounded),
                  label: Text(
                    _isPublishing ? 'جاري إنشاء الجلسة...' : 'إنشاء جلسة',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Color surfaceColor,
    required Color hairlineColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hairlineColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSessionTypeRadio({
    required SessionType type,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryColor,
    required bool isDark,
  }) {
    final isSelected = _sessionType == type;
    return InkWell(
      onTap: () => setState(() {
        _sessionType = type;
        if (type == SessionType.individual) _maxAttendees = 1;
        if (type == SessionType.group && _maxAttendees == 1) _maxAttendees = 10;
      }),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withValues(alpha: isDark ? 0.25 : 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryColor : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? primaryColor : (isDark ? Colors.white54 : AppColors.textSecondary), size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? primaryColor : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationChoice(int minutes, Color primaryColor, bool isDark) {
    final isSelected = _durationMinutes == minutes;
    return Expanded(
      child: ChoiceChip(
        label: Center(
          child: Text(
            '$minutes دقيقة',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? (isDark ? AppColors.darkOnPrimary : Colors.white)
                  : (isDark ? Colors.white70 : AppColors.textPrimary),
            ),
          ),
        ),
        selected: isSelected,
        selectedColor: primaryColor,
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (_) => setState(() => _durationMinutes = minutes),
      ),
    );
  }
}
