// مطور 1
// فيجما: تفاصيل الجلسة - عرض الشارح (الربط الحي بالضمان والفايربيز)

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/app_models.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/data/auth_service.dart';
import '../../timebank/application/timebank_pure_logic.dart';
import '../../timebank/data/timebank_repository.dart';

class SessionDetailsTeacherScreen extends ConsumerStatefulWidget {
  final TimeBankSessionModel? session;
  const SessionDetailsTeacherScreen({super.key, this.session});

  @override
  ConsumerState<SessionDetailsTeacherScreen> createState() => _SessionDetailsTeacherScreenState();
}

class _SessionDetailsTeacherScreenState extends ConsumerState<SessionDetailsTeacherScreen> {
  bool _isCancelling = false;
  bool _isProcessingAction = false;

  Future<void> _acceptSession(TimeBankSessionModel session) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    setState(() => _isProcessingAction = true);
    try {
      await ref.read(timeBankRepositoryProvider).acceptSession(
            sessionId: session.id,
            teacherId: user.uid,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم قبول جلسة الشرح وتأكيد الموعد بنجاح.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر قبول الجلسة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _rejectSession(TimeBankSessionModel session) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('الاعتذار عن الجلسة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إذا اعتذرت عن الجلسة، فسيتم استرداد عملة الوقت بالكامل إلى محفظة زميلك المتعلم فوراً.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'سبب الاعتذار (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: context.tokens.danger),
            child: const Text('تأكيد الاعتذار', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessingAction = true);
    try {
      await ref.read(timeBankRepositoryProvider).rejectSession(
            sessionId: session.id,
            teacherId: user.uid,
            reason: controller.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الاعتذار عن الجلسة وإعادة عملة الوقت للمتعلم.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الاعتذار عن الجلسة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _claimAutoRelease(TimeBankSessionModel session) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    setState(() => _isProcessingAction = true);
    try {
      await ref.read(timeBankRepositoryProvider).claimTeacherAutoRelease(
            sessionId: session.id,
            teacherId: user.uid,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحرير عملة الوقت إلى محفظتك بنجاح.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحرير العملة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _markDone(TimeBankSessionModel session) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    setState(() => _isProcessingAction = true);
    try {
      await ref.read(timeBankRepositoryProvider).markSessionDoneByTeacher(
            sessionId: session.id,
            teacherId: user.uid,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل الجلسة كمنجزة، بانتظار تأكيد المتعلم.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تسجيل تم الشرح: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _showEditMeetingUrlDialog(TimeBankSessionModel session) async {
    final controller = TextEditingController(text: session.meetingUrl ?? '');
    String? errorText;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('رابط جلسة الشرح الأونلاين', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أدخل رابط Google Meet أو Zoom ليتمكن زميلك من الانضمام للجلسة:',
                style: TextStyle(fontSize: 12, color: context.tokens.textMedium, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: 'https://meet.google.com/xyz-abcd-efg',
                  errorText: errorText,
                  border: OutlineInputBorder(borderRadius: AppRadii.controlRadius),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final url = controller.text.trim();
                final uri = Uri.tryParse(url);
                if (uri == null || uri.scheme != 'https') {
                  setDialogState(() => errorText = 'يجب أن يبدأ الرابط بـ https://');
                  return;
                }
                final host = uri.host.toLowerCase();
                final isAllowed = host == 'meet.google.com' ||
                    host == 'zoom.us' ||
                    host.endsWith('.zoom.us') ||
                    host == 'teams.microsoft.com';
                if (!isAllowed) {
                  setDialogState(() => errorText = 'مسموح بروابط Google Meet أو Zoom أو MS Teams فقط');
                  return;
                }

                try {
                  await ref.read(timeBankRepositoryProvider).updateSessionMeetingUrl(
                        sessionId: session.id,
                        teacherId: session.teacherId,
                        meetingUrl: url,
                      );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  setDialogState(() => errorText = 'تعذر الحفظ: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: context.tokens.brand),
              child: const Text('حفظ الرابط', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث رابط الاجتماع بنجاح.')),
      );
    }
  }

  Future<void> _cancelSession(TimeBankSessionModel session) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إلغاء الجلسة من قِبل الشارح'),
        content: const Text(
          'إذا قمت بإلغاء الجلسة كمعلم، فسيتم استرداد عملة الوقت بالكامل إلى محفظة المتعلّم فوراً.\nهل أنت متأكد من الإلغاء؟',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: context.tokens.danger),
            child: const Text('تأكيد الإلغاء', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);

    try {
      await ref.read(timeBankRepositoryProvider).cancelSessionWithEscrow(
            sessionId: session.id,
            cancellingUserId: user.uid,
            reason: 'إلغاء من قِبل الشارح',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء الجلسة واسترداد العملة للمتعلم.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إلغاء الجلسة: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final learnerName = session?.learnerName ?? 'المتعلّم';
    final learnerInitials = learnerName.trim().isNotEmpty
        ? learnerName.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('.')
        : 'ز.ن';
    final courseName = session?.courseName ?? 'المادة الدراسية';
    final topic = session?.topic ?? 'موضوع الشرح';
    final duration = '${session?.durationMinutes ?? 60} دقيقة كاملة';
    final location = session?.location ?? 'مبنى الكلية';
    final escrowStatus = session?.escrowStatus ?? 'held';
    final isHeld = escrowStatus == 'held';
    final isReleased = escrowStatus == 'released_to_teacher';
    final isRefunded = escrowStatus == 'refunded_to_learner';

    final tokens = context.tokens;
    final cardColor = tokens.surface;
    final hairline = tokens.border;
    final onSurface = tokens.textHigh;
    final primaryColor = tokens.brand;
    final primaryContainer = tokens.brandContainer;
    final textSecondary = tokens.textMedium;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_forward_ios_rounded, color: onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'تفاصيل الجلسة (الشارح)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onSurface),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Learner info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: hairline),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: primaryContainer,
                      child: Text(learnerInitials, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$learnerName (المتعلّم)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onSurface)),
                          const SizedBox(height: 2),
                          Text('الفرقة الثانية • كلية الحاسبات والذكاء الاصطناعي', style: TextStyle(fontSize: 12, color: textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Reward alert
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isReleased
                      ? tokens.successContainer
                      : (isRefunded ? tokens.dangerContainer : tokens.warningContainer),
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(
                    color: isReleased
                        ? tokens.success
                        : (isRefunded ? tokens.danger : tokens.warning),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isReleased
                          ? Icons.check_circle_rounded
                          : (isRefunded ? Icons.info_outline_rounded : Icons.stars_rounded),
                      color: isReleased ? tokens.success : (isRefunded ? tokens.danger : tokens.warning),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isReleased
                            ? 'تم إتمام الشرح وتحرير عملة الوقت إلى محفظتك بنجاح. تقييم المتعلم لك: ${session?.rating ?? 5} نجوم.'
                            : (isRefunded
                                ? 'تم إلغاء هذه الجلسة واسترداد العملة للمتعلم.'
                                : 'الجلسة مؤكدة ومحجوزة في الضمان. بعد انتهاء الشرح وتأكيد المتعلم، ستضاف 1 عملة وقت إلى محفظتك فوراً.'),
                        style: TextStyle(
                          fontSize: 13,
                          color: isReleased ? tokens.success : (isRefunded ? tokens.danger : tokens.textHigh),
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Details
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: hairline),
                ),
                child: Column(
                  children: [
                    _RowItem('المادة', courseName),
                    Divider(height: 20, color: hairline),
                    _RowItem('الموضوع المطلوب', topic),
                    Divider(height: 20, color: hairline),
                    _RowItem('المدة المقررة', duration),
                    Divider(height: 20, color: hairline),
                    _RowItem('المكان / طريقة اللقاء', session?.mode == 'online' ? 'عبر الإنترنت' : location),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (session?.mode == 'online') ...[
                if (session?.meetingUrl != null && session!.meetingUrl!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.brandContainer.withValues(alpha: 0.4),
                      borderRadius: AppRadii.cardRadius,
                      border: Border.all(color: tokens.brand),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.videocam_rounded, color: tokens.brand, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'رابط جلسة الشرح الأونلاين',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: tokens.brand),
                                ),
                              ],
                            ),
                            if (isHeld)
                              TextButton.icon(
                                onPressed: () => _showEditMeetingUrlDialog(session),
                                icon: Icon(Icons.edit_outlined, size: 16),
                                label: Text('تعديل', style: TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          session.meetingUrl!,
                          style: TextStyle(fontSize: 12, color: tokens.textMedium),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: session.meetingUrl!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم نسخ رابط الاجتماع بنجاح.')),
                            );
                          },
                          icon: Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                          label: Text('نسخ رابط الاجتماع', style: TextStyle(color: Colors.white, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.brand,
                            shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.warningContainer,
                      borderRadius: AppRadii.cardRadius,
                      border: Border.all(color: tokens.warning),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: tokens.warning, size: 22),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'هذه الجلسة أونلاين ولكنك لم تقم بإضافة رابط اللقاء بعد!',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textHigh),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'يرجى إنشاء رابط Google Meet أو Zoom وإضافته هنا ليتمكن زميلك من الانضمام للجلسة.',
                          style: TextStyle(fontSize: 12, color: context.tokens.textMedium, height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () => _showEditMeetingUrlDialog(session!),
                          icon: Icon(Icons.add_link_rounded, size: 18, color: Colors.white),
                          label: Text('أضف رابط الاجتماع الآن', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.brand,
                            shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
              ] else
                const SizedBox(height: 8),

              // Chat Button
              if (session != null) ...[
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/session-chat', extra: session),
                    icon: Icon(Icons.forum_outlined, color: tokens.brand),
                    label: Text(
                      'محادثة لتنسيق الجلسة مع $learnerName',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.brand),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: tokens.brand),
                      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (session != null && session.status == 'disputed') ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tokens.dangerContainer,
                    borderRadius: AppRadii.controlRadius,
                    border: Border.all(color: tokens.danger),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.gavel_rounded, color: tokens.danger, size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'هذه الجلسة قيد النزاع بناءً على اعتراض المتعلم. العملة محتجزة في الضمان لحين المراجعة اليدوية من الإدارة.',
                          style: TextStyle(fontSize: 13, color: tokens.textHigh, fontWeight: FontWeight.bold, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (session != null && session.status == 'pending') ...[
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessingAction ? null : () => _acceptSession(session),
                    icon: Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                    label: Text(
                      _isProcessingAction ? 'جاري القبول...' : 'قبول الجلسة وتأكيد الموعد',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.brand,
                      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isProcessingAction ? null : () => _rejectSession(session),
                    icon: Icon(Icons.close_rounded, color: tokens.danger),
                    label: Text(
                      _isProcessingAction ? 'جاري معالجة الطلب...' : 'اعتذار عن الجلسة وإعادة العملة',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.danger),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: tokens.danger),
                      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ] else if (isHeld && session?.status != 'disputed') ...[
                if (session != null && session.status == 'confirmed') ...[
                  if (session.teacherMarkedDoneAt != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.brand.withValues(alpha: 0.1),
                        borderRadius: AppRadii.controlRadius,
                        border: Border.all(color: tokens.brand),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, color: tokens.brand, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تم تسجيل الجلسة كمنجزة، بانتظار تأكيد وتقييم المتعلم.',
                              style: TextStyle(fontSize: 12, color: tokens.textHigh, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (TimeBankPureLogic.canTeacherClaimAutoRelease(
                      status: session.status,
                      escrowStatus: session.escrowStatus,
                      teacherMarkedDoneAt: session.teacherMarkedDoneAt,
                      scheduledAt: session.scheduledAt,
                    )) ...[
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessingAction ? null : () => _claimAutoRelease(session),
                          icon: Icon(Icons.monetization_on_outlined, color: Colors.white),
                          label: Text(
                            _isProcessingAction ? 'جاري تحرير العملة...' : 'تحرير عملة الوقت',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.brand,
                            shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ] else if (session.scheduledAt == null || DateTime.now().isAfter(session.scheduledAt!)) ...[
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessingAction ? null : () => _markDone(session),
                        icon: Icon(Icons.school_rounded, color: Colors.white),
                        label: Text(
                          _isProcessingAction ? 'جاري التأكيد...' : 'تسجيل إتمام الشرح',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.brand,
                          shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isCancelling ? null : () => session != null ? _cancelSession(session) : null,
                    icon: Icon(Icons.cancel_outlined, color: tokens.danger),
                    label: Text(
                      _isCancelling ? 'جاري إلغاء الجلسة...' : 'إلغاء الجلسة واعتذار للمتعلم',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.danger),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: tokens.danger),
                      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final String label;
  final String value;
  const _RowItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: tokens.textMedium,
          ),
        ),
      ],
    );
  }
}