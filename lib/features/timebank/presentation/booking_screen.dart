// مطور 3
// فيجما: حجز جلسة - ذاكر وعلّم (الربط الحي بالضمان والفايربيز)

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_models.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/data/auth_service.dart';
import '../application/timebank_pure_logic.dart';
import '../data/timebank_repository.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final TimeBankOfferModel? offer;
  const BookingScreen({super.key, this.offer});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  bool _isBooking = false;
  late int _selectedDuration;
  DateTime? _selectedSlotDateTime;

  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.offer?.durationMinutes ?? 60;
    if (_selectedDuration != 30 && _selectedDuration != 60) {
      _selectedDuration = 60;
    }
  }

  Future<void> _handleBookSession(int currentCoins) async {
    final offer = widget.offer;
    if (offer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بيانات العرض غير متوفرة')),
      );
      return;
    }

    if (_selectedSlotDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار موعد محدد ومناسب للجلسة')),
      );
      return;
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
              content: const Text('يجب تأكيد بريدك الإلكتروني أولاً لحجز الجلسات وحماية رصيدك'),
              action: SnackBarAction(
                label: 'أنا أكدت بريدي',
                textColor: Colors.amber,
                onPressed: () async {
                  final v = await ref.read(authServiceProvider).reloadUserAndCheckVerified();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(v ? 'تم التحقق من البريد الإلكتروني بنجاح.' : 'لم يتم التأكيد بعد، يرجى مراجعة البريد الإلكتروني.')),
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

    if (!mounted) return;

    final isAlreadyEnrolled = offer.isGroupSession && offer.enrolledLearnerIds.contains(user.uid);
    if (isAlreadyEnrolled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أنت مسجل بالفعل في هذه الجلسة.')),
      );
      return;
    }

    final isFull = offer.isGroupSession &&
        offer.maxLearners != null &&
        offer.enrolledLearnerIds.length >= offer.maxLearners!;
    if (isFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عفواً، اكتملت جميع المقاعد في هذه الجلسة الجماعية')),
      );
      return;
    }

    if (currentCoins < AppConstants.sessionCostCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رصيدك لا يكفي لحجز الجلسة (المطلوب: 1 عملة وقت)')),
      );
      return;
    }

    setState(() => _isBooking = true);

    try {
      final profileAsync = ref.read(userProfileStreamProvider);
      final profileName = profileAsync.value?.data()?['name'] as String? ?? user.displayName ?? 'زميل';

      final chosenStart = _selectedSlotDateTime!;
      final chosenWeekday = (chosenStart.weekday + 1) % 7;
      final chosenDayName = OfferTimeSlot.appWeekdayNames[chosenWeekday] ?? 'السبت';
      final startMin = chosenStart.hour * 60 + chosenStart.minute;
      final endMin = startMin + _selectedDuration;
      final chosenTimeFormatted = '${OfferTimeSlot.formatMinutes(startMin)} – ${OfferTimeSlot.formatMinutes(endMin)}';

      final sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}_${user.uid.substring(0, 5)}';
      final session = TimeBankSessionModel(
        id: sessionId,
        learnerId: user.uid,
        learnerName: profileName,
        teacherId: offer.teacherId,
        teacherName: offer.teacherName,
        teacherInitials: offer.teacherName.trim().isNotEmpty
            ? offer.teacherName.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('.')
            : 'ز.م',
        courseName: offer.courseName,
        courseCode: offer.courseCode,
        topic: offer.topic,
        day: chosenDayName,
        time: chosenTimeFormatted,
        durationMinutes: _selectedDuration,
        location: offer.location,
        mode: offer.mode,
        costCoins: AppConstants.sessionCostCoins,
        status: 'confirmed',
        escrowStatus: 'held',
        rating: null,
        scheduledAt: chosenStart, // حقيقي ومخزن كـ Timestamp
        createdAt: DateTime.now(),
        isGroupSession: offer.isGroupSession,
        maxLearners: offer.maxLearners,
        meetingUrl: offer.meetingUrl,
      );

      await ref.read(timeBankRepositoryProvider).bookSessionWithEscrow(
            session: session,
            offerId: offer.id,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حجز الجلسة بنجاح وحُجزت عملة الوقت في الضمان.')),
        );
        context.pushReplacement('/my-sessions');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إتمام الحجز: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBooking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final coins = ref.watch(userTimeCoinsProvider);

    final planner = ref.watch(plannerProvider);
    final teacherSlots = widget.offer?.slots ?? [];
    final effectiveSlots = teacherSlots.isNotEmpty
        ? teacherSlots
        : [
            OfferTimeSlot(
              weekday: OfferTimeSlot.appWeekdayIndexes[widget.offer?.day ?? 'الأحد'] ?? 1,
              startMin: 600,
              endMin: 720,
            ),
          ];

    final availableBookableSlots = TimeBankPureLogic.generateBookableSlots(
      teacherSlots: effectiveSlots,
      durationMinutes: _selectedDuration,
      learnerLectures: planner.lectureSchedule,
      learnerStudyBlocks: planner.studyBlocks,
    );

    if (_selectedSlotDateTime != null && !availableBookableSlots.any((s) => s.dateTime == _selectedSlotDateTime)) {
      _selectedSlotDateTime = null;
    }
    if (_selectedSlotDateTime == null && availableBookableSlots.isNotEmpty) {
      _selectedSlotDateTime = availableBookableSlots.first.dateTime;
    }

    final teacherName = offer?.teacherName ?? 'زميل دراسة';
    final teacherInitials = teacherName.trim().isNotEmpty
        ? teacherName.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('.')
        : 'ز.م';
    final courseName = offer?.courseName ?? 'المادة الدراسية';
    final topic = offer?.topic ?? 'شرح موضوع دراسي وتطبيق عملي';
    final location = offer?.location ?? 'مبنى الكلية';

    String selectedSlotText = 'يرجى اختيار موعد متاح';
    if (_selectedSlotDateTime != null) {
      final chosenWeekday = (_selectedSlotDateTime!.weekday + 1) % 7;
      final dayName = OfferTimeSlot.appWeekdayNames[chosenWeekday] ?? '';
      final startMin = _selectedSlotDateTime!.hour * 60 + _selectedSlotDateTime!.minute;
      final endMin = startMin + _selectedDuration;
      selectedSlotText = '$dayName ${_selectedSlotDateTime!.day}/${_selectedSlotDateTime!.month} • ${OfferTimeSlot.formatMinutes(startMin)} – ${OfferTimeSlot.formatMinutes(endMin)} ($_selectedDuration دقيقة)';
    }

    final tokens = context.tokens;
    final hairline = tokens.border;

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
          'تأكيد حجز الجلسة',
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
              // Teacher card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: hairline),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: tokens.brandContainer,
                      child: Text(teacherInitials, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tokens.brand)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(teacherName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                          const SizedBox(height: 2),
                          Text('الفرقة الثانية • كلية الحاسبات والذكاء الاصطناعي', style: TextStyle(fontSize: 12, color: tokens.textMedium)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.star_rounded, size: 16, color: tokens.coin),
                              SizedBox(width: 4),
                              Text('تقييم ممتاز في بنك الوقت', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.brand)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (offer != null && offer.isGroupSession) ...[
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tokens.brand.withValues(alpha: 0.1),
                    borderRadius: AppRadii.cardRadius,
                    border: Border.all(color: tokens.brand.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tokens.brand,
                          borderRadius: AppRadii.controlRadius,
                        ),
                        child: Icon(Icons.groups_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'جلسة شرح جماعية',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.brand),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'المقاعد المحجوزة: ${offer.enrolledLearnerIds.length} من أصل ${offer.maxLearners ?? 10}',
                              style: TextStyle(fontSize: 11, color: tokens.textMedium),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (offer != null && offer.isFlexibleRange) ...[
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tokens.coin.withValues(alpha: 0.12),
                    borderRadius: AppRadii.cardRadius,
                    border: Border.all(color: tokens.coin.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tokens.coin,
                          borderRadius: AppRadii.controlRadius,
                        ),
                        child: Icon(Icons.access_time_filled_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'موعد مرن للشرح',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'الشارح متاح في النطاق (${offer.timeRangeStart ?? ''} – ${offer.timeRangeEnd ?? ''})، اختر الموعد الأنسب لك أدناه.',
                              style: TextStyle(fontSize: 11, color: tokens.textMedium),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Duration selector (30 or 60 minutes)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مدة الجلسة',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('60 دقيقة (ساعة كاملة)')),
                            selected: _selectedDuration == 60,
                            selectedColor: tokens.brandContainer,
                            labelStyle: TextStyle(
                              color: _selectedDuration == 60 ? tokens.brand : Theme.of(context).colorScheme.onSurface,
                              fontWeight: _selectedDuration == 60 ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _selectedDuration = 60);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('30 دقيقة (نصف ساعة)')),
                            selected: _selectedDuration == 30,
                            selectedColor: tokens.brandContainer,
                            labelStyle: TextStyle(
                              color: _selectedDuration == 30 ? tokens.brand : Theme.of(context).colorScheme.onSurface,
                              fontWeight: _selectedDuration == 30 ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _selectedDuration = 30);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Concrete slot picker (Between 2 hours & 14 days ahead, hiding overlapping slots)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'اختر موعد الجلسة',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        Text(
                          '${availableBookableSlots.length} مواعيد شاغرة',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.brand),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'المواعيد المستبعدة تلقائياً: ما قبل ساعتين، وما بعد 14 يوماً، وما يتعارض مع محاضراتك.',
                      style: TextStyle(fontSize: 11, color: tokens.textMedium),
                    ),
                    const SizedBox(height: 12),
                    if (availableBookableSlots.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tokens.danger.withValues(alpha: 0.1),
                          borderRadius: AppRadii.controlRadius,
                          border: Border.all(color: tokens.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: tokens.danger, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'لا توجد مواعيد متاحة تتوافق مع جدول محاضراتك خلال الـ 14 يوماً القادمة.',
                                style: TextStyle(fontSize: 12, color: tokens.danger),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: AppRadii.controlRadius,
                          border: Border.all(color: hairline),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<DateTime>(
                            value: _selectedSlotDateTime,
                            isExpanded: true,
                            hint: const Text('اختر الموعد المناسب لك'),
                            items: availableBookableSlots.map((slot) {
                              return DropdownMenuItem<DateTime>(
                                value: slot.dateTime,
                                child: Text(
                                  '${slot.dateFormatted} • ${slot.timeFormatted}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedSlotDateTime = val);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Session details card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: hairline),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(context, Icons.menu_book_rounded, 'المادة', courseName),
                    Divider(height: 20, color: hairline),
                    _buildDetailRow(context, Icons.topic_outlined, 'الموضوع', topic),
                    Divider(height: 20, color: hairline),
                    _buildDetailRow(context, Icons.calendar_today_outlined, 'الموعد المختار', selectedSlotText),
                    Divider(height: 20, color: hairline),
                    _buildDetailRow(
                      context,
                      offer?.mode == 'online'
                          ? Icons.videocam_rounded
                          : Icons.location_on_outlined,
                      offer?.mode == 'online'
                          ? 'طريقة اللقاء'
                          : 'المكان',
                      offer?.mode == 'online'
                          ? 'أونلاين عن بُعد (Google Meet / Zoom)'
                          : location,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Escrow notice card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.warningContainer,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: tokens.warning),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: tokens.warning, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'نظام الضمان الآمن (Escrow System)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textHigh),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'رصيدك الحالي: $coins عملات وقت • تكلفة الجلسة: 1 عملة.\nتُعلّق العملة كأمانة، ولا تُحوّل لحساب الزميل إلا بعد انتهاء الشرح وتأكيدك.',
                            style: TextStyle(fontSize: 11, color: tokens.textMedium, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Button "أرسل طلب الجلسة" -> /my-sessions
              Builder(
                builder: (context) {
                  final currentUserId = ref.watch(authServiceProvider).currentUser?.uid ?? '';
                  final isAlreadyEnrolled = offer != null &&
                      offer.isGroupSession &&
                      offer.enrolledLearnerIds.contains(currentUserId);
                  final isFull = offer != null &&
                      offer.isGroupSession &&
                      offer.maxLearners != null &&
                      offer.enrolledLearnerIds.length >= offer.maxLearners!;

                  final isButtonDisabled = _isBooking ||
                      coins < AppConstants.sessionCostCoins ||
                      isAlreadyEnrolled ||
                      isFull;

                  String buttonLabel = 'تأكيد الحجز وخصم عملة واحدة للضمان';
                  if (_isBooking) {
                    buttonLabel = 'جاري تأكيد الحجز وحفظ الضمان...';
                  } else if (isAlreadyEnrolled) {
                    buttonLabel = 'أنت مسجل بالفعل في هذه الجلسة';
                  } else if (isFull) {
                    buttonLabel = 'اكتملت جميع مقاعد الجلسة';
                  } else if (coins < AppConstants.sessionCostCoins) {
                    buttonLabel = 'رصيدك لا يكفي للحجز (تحتاج 1 عملة)';
                  }

                  return SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isButtonDisabled ? null : () => _handleBookSession(coins),
                      icon: _isBooking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      label: Text(
                        buttonLabel,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brand,
                        disabledBackgroundColor: Colors.grey.shade400,
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    final tokens = context.tokens;
    return Row(
      children: [
        Icon(icon, size: 20, color: tokens.brand),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 13, color: tokens.textMedium)),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}