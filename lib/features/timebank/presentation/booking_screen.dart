// مطور 3
// فيجما: حجز جلسة - ذاكر وعلّم (الربط الحي بالضمان والفايربيز)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_service.dart';
import '../data/timebank_repository.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final TimeBankOfferModel? offer;
  const BookingScreen({super.key, this.offer});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  bool _isBooking = false;

  Future<void> _handleBookSession(int currentCoins) async {
    final offer = widget.offer;
    if (offer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بيانات العرض غير متوفرة')),
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
                      SnackBar(content: Text(v ? 'تم التحقق من بريدك بنجاح! يمكنك الآن الحجز 🎉' : 'لم يتم التأكيد بعد، يرجى مراجعة بريدك 📩')),
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
        day: offer.day,
        time: offer.time,
        durationMinutes: offer.durationMinutes,
        location: offer.location,
        mode: offer.mode,
        costCoins: AppConstants.sessionCostCoins,
        status: 'confirmed',
        escrowStatus: 'held',
        rating: null,
        scheduledAt: DateTime.now().add(const Duration(hours: 24)),
        createdAt: DateTime.now(),
      );

      await ref.read(timeBankRepositoryProvider).bookSessionWithEscrow(session: session);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حجز الجلسة بنجاح مع ${offer.teacherName}! وحُجزت 1 عملة في الضمان 🚀')),
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
    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final userDoc = userProfileAsync.value?.data();
    final coins = (userDoc?['timeCoins'] as num?)?.toInt() ?? 2;

    final teacherName = offer?.teacherName ?? 'زميل دراسة';
    final teacherInitials = teacherName.trim().isNotEmpty
        ? teacherName.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('.')
        : 'ز.م';
    final courseName = offer?.courseName ?? 'المادة الدراسية';
    final topic = offer?.topic ?? 'شرح موضوع دراسي وتطبيق عملي';
    final dayTime = offer != null ? '${offer.day} • ${offer.time} (${offer.durationMinutes} دقيقة)' : 'ميعاد متفق عليه';
    final location = offer?.location ?? 'مبنى الكلية';

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
          'تأكيد حجز الجلسة ✍️',
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
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(teacherInitials, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(teacherName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                          const SizedBox(height: 2),
                          const Text('الفرقة الثانية • كلية الحاسبات والذكاء الاصطناعي', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(Icons.star_rounded, size: 16, color: AppColors.pointsAmber),
                              SizedBox(width: 4),
                              Text('تقييم ممتاز في بنك الوقت', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                        ],
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
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(context, Icons.menu_book_rounded, 'المادة', courseName),
                    const Divider(height: 20, color: AppColors.hairline),
                    _buildDetailRow(context, Icons.topic_outlined, 'الموضوع', topic),
                    const Divider(height: 20, color: AppColors.hairline),
                    _buildDetailRow(context, Icons.calendar_today_outlined, 'الموعد', dayTime),
                    const Divider(height: 20, color: AppColors.hairline),
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
                  color: AppColors.pointsAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.pointsAmber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.pointsAmber, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'نظام الضمان الآمن (Escrow System)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF664700)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'رصيدك الحالي: $coins عملات وقت • تكلفة الجلسة: 1 عملة.\nتُعلّق العملة كأمانة، ولا تُحوّل لحساب الزميل إلا بعد انتهاء الشرح وتأكيدك.',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF855D00), height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Button "أرسل طلب الجلسة" -> /my-sessions
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_isBooking || coins < AppConstants.sessionCostCoins)
                      ? null
                      : () => _handleBookSession(coins),
                  icon: _isBooking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  label: Text(
                    _isBooking
                        ? 'جاري تأكيد الحجز وحفظ الضمان...'
                        : (coins < AppConstants.sessionCostCoins ? 'رصيدك لا يكفي للحجز (تحتاج 1 عملة)' : 'تأكيد الحجز وخصم عملة واحدة للضمان'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey.shade400,
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

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
