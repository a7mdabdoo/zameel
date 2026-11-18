// مطور 1
// تفاصيل الجلسة الموحدة للجلسات الفردية والجماعية مع دعم Google Meet والمحادثة والضمان

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/app_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_service.dart';
import '../../timebank/data/timebank_repository.dart';
import 'widgets/session_chat_sheet.dart';

class SessionDetailsScreen extends ConsumerStatefulWidget {
  final TimeBankSessionModel? session;
  final TimeBankOfferModel? offer;

  const SessionDetailsScreen({
    super.key,
    this.session,
    this.offer,
  });

  @override
  ConsumerState<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends ConsumerState<SessionDetailsScreen> {
  bool _isProcessing = false;

  Future<void> _launchMeeting(String url) async {
    String finalUrl = url.trim();
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }
    final uri = Uri.tryParse(finalUrl);
    if (uri != null) {
      try {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر فتح الرابط تلقائياً: $finalUrl')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في تشغيل الرابط: $e')),
          );
        }
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ رابط الاجتماع للحافظة 📋'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _settleSessionAsTeacher(String offerId, String teacherId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إنهاء الجلسة وصرف العملات 🪙'),
        content: const Text(
          'هل انتهت جلسة الشرح مع زملائك؟\n'
          'سيتم احتساب أجر الشرح وفقاً لنظام الاقتصاد المتدرج وإيداع العملات في محفظتك فوراً.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد وصرف العملات')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final reward = await ref.read(timeBankRepositoryProvider).settleSessionCompletion(
            offerId: offerId,
            settledByUserId: teacherId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنهاء الجلسة بنجاح وإيداع $reward عملات في محفظتك! 🎉'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إنهاء الجلسة: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _cancelSessionAsLearner(TimeBankSessionModel session) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء حجز الجلسة'),
        content: const Text(
          'قواعد استرداد الضمان:\n'
          '• الإلغاء قبل الموعد بأكثر من ساعتين: استرداد عملة الوقت كاملة فوراً إلى محفظتك.\n'
          '• الإلغاء قبل الموعد بأقل من ساعتين: تُحوّل العملة للزميل الشارح كتعويض عن حجز وقته.\n\n'
          'هل تريد الاستمرار في الإلغاء؟',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('تأكيد الإلغاء', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await ref.read(timeBankRepositoryProvider).cancelSessionWithEscrow(
            sessionId: session.id,
            cancellingUserId: user.uid,
            reason: 'إلغاء من قبل المتعلم',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء الجلسة بنجاح واسترداد العملة وفق قواعد الضمان 🔄')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الإلغاء: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    final currentUserId = user?.uid ?? '';

    final session = widget.session;
    final offer = widget.offer;

    // استخراج بيانات الجلسة من SessionModel أو OfferModel
    final courseName = session?.courseName ?? offer?.courseName ?? 'مقرر دراسي';
    final topic = session?.topic ?? offer?.topic ?? 'موضوع الشرح';
    final teacherName = session?.teacherName ?? offer?.teacherName ?? 'زميل';
    final teacherId = session?.teacherId ?? offer?.teacherId ?? '';
    final isTeacher = currentUserId == teacherId;
    final isGroup = (session?.isGroupSession ?? offer?.isGroupSession) ?? false;
    final scheduledDay = session?.day ?? offer?.day ?? 'الخميس';
    final scheduledTime = session?.time ?? offer?.time ?? '08:00 م';
    final meetingUrl = session?.meetingUrl ?? offer?.meetingUrl;
    final attendees = session?.enrolledLearnerIds ?? offer?.attendeeIds ?? <String>[];
    final maxAttendees = session?.maxLearners ?? offer?.maxAttendees ?? (isGroup ? 50 : 1);
    final status = session?.status ?? (offer?.isCompleted == true ? 'completed' : 'confirmed');

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final surfaceColor = theme.cardTheme.color ?? (isDark ? const Color(0xFF1E293B) : Colors.white);
    final hairlineColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        title: Text(
          isGroup ? 'تفاصيل الجلسة الجماعية 👥' : 'تفاصيل الجلسة الخاصة 👤',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (session != null)
            IconButton(
              tooltip: 'محادثة الجلسة',
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              onPressed: () => SessionChatSheet.show(
                context,
                session,
                isTeacher ? session.learnerName : session.teacherName,
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. بطاقة الرأس الأساسية
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: hairlineColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          courseName,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryColor),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isGroup
                              ? (isDark ? const Color(0xFF0369A1).withValues(alpha: 0.3) : const Color(0xFFE0F2FE))
                              : (isDark ? const Color(0xFF7C3AED).withValues(alpha: 0.3) : const Color(0xFFEDE9FE)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isGroup ? '👥 جلسة جماعية (Webinar)' : '👤 جلسة خاصة (1-on-1)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isGroup
                                ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                                : (isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    topic,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: primaryColor.withValues(alpha: 0.15),
                        child: Text(
                          teacherName.isNotEmpty ? teacherName.substring(0, 1) : 'ز',
                          style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الزميل الشارح: $teacherName ${isTeacher ? "👑" : ""}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'جلسة أونلاين 100% • الضمان المالي مفعل 🛡️',
                            style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. زر الانضمام المباشر للاجتماع (Google Meet / Zoom Button)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF064E3B), const Color(0xFF022C22)]
                      : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.videocam_rounded, color: AppColors.success, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'قاعة البث المباشر (Google Meet)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (meetingUrl != null && meetingUrl.isNotEmpty) ...[
                    Text(
                      meetingUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _launchMeeting(meetingUrl),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.open_in_new_rounded, size: 18),
                            label: const Text(
                              'انضم للاجتماع الآن 📹',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'نسخ الرابط',
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: () => _copyToClipboard(meetingUrl),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Text(
                      'لم يقم الزميل الشارح بتعيين رابط الاجتماع بعد. سيصلك إشعار فور تعيينه ومشاركته في محادثة الجلسة 💬',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. الموعد والحالة
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: hairlineColor),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('موعد الجلسة وحالة الحجز 📅', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.access_time_filled_rounded, size: 18, color: primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$scheduledDay، $scheduledTime',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status == 'completed' ? 'مكتملة 🎉' : 'حجز مؤكد ⚡',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 4. ودجت الحضور للجلسات الجماعية
            if (isGroup) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: hairlineColor),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('قائمة الزملاء المشاركين 👥', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('${attendees.length} من $maxAttendees زميل', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (attendees.isEmpty)
                      const Text('لا يوجد مشاركون حتى الآن', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: attendees.map((id) {
                          final isMe = id == currentUserId;
                          return Chip(
                            avatar: CircleAvatar(
                              radius: 10,
                              backgroundColor: isMe ? primaryColor : Colors.grey,
                              child: Text(isMe ? 'أ' : 'ز', style: const TextStyle(fontSize: 9, color: Colors.white)),
                            ),
                            label: Text(
                              isMe ? 'أنت ✅' : 'زميل منضم',
                              style: TextStyle(fontSize: 11, fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
                            ),
                            backgroundColor: isMe ? primaryColor.withValues(alpha: isDark ? 0.3 : 0.1) : null,
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // 5. أزرار التحكم والإجراءات
            if (session != null) ...[
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/session-chat', extra: session),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('فتح المحادثة الفورية مع الزميل 💬', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (isTeacher && (session?.status != 'completed' && offer?.isCompleted != true)) ...[
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _settleSessionAsTeacher(offer?.id ?? session?.id ?? '', teacherId),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('إنهاء الجلسة وصرف العملات للمحفظة 🪙', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else if (!isTeacher && session != null && session.status == 'confirmed') ...[
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: () => context.push('/session-rating', extra: session),
                  icon: const Icon(Icons.star_rounded),
                  label: const Text('تأكيد انتهاء الشرح وتقييم الزميل ⭐', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _isProcessing ? null : () => _cancelSessionAsLearner(session),
                icon: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 18),
                label: const Text('إلغاء حجز الجلسة واسترداد العملة', style: TextStyle(color: AppColors.error, fontSize: 12)),
              ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
