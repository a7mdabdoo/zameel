// مطور 1
// فيجما: تأكيد الجلسة - عرض المتعلّم (الربط الحي بالضمان والتقييم)

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/app_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_service.dart';
import '../../timebank/application/timebank_pure_logic.dart';
import '../../timebank/data/timebank_repository.dart';

class SessionDetailsLearnerScreen extends ConsumerStatefulWidget {
  final TimeBankSessionModel? session;
  const SessionDetailsLearnerScreen({super.key, this.session});

  @override
  ConsumerState<SessionDetailsLearnerScreen> createState() => _SessionDetailsLearnerScreenState();
}

class _SessionDetailsLearnerScreenState extends ConsumerState<SessionDetailsLearnerScreen> {
  bool _isCancelling = false;

  Future<void> _cancelSession(TimeBankSessionModel session) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء حجز الجلسة'),
        content: const Text(
          'قواعد استرداد الضمان:\n'
          '• إذا ألغيت قبل الموعد بأكثر من ساعتين: يتم استرداد عملة الوقت كاملة لمحفظتك.\n'
          '• إذا ألغيت قبل الموعد بأقل من ساعتين: تُحوّل العملة للزميل الشارح تعويضاً عن حجز وقته.\n\n'
          'هل أنت متأكد من رغبتك في الإلغاء؟',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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
            reason: 'إلغاء من قِبل المتعلّم',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء الجلسة بنجاح وفقاً لقواعد الضمان 🔄')),
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

  Future<void> _claimExpiredRefund(TimeBankSessionModel session) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    setState(() => _isCancelling = true);
    try {
      await ref.read(timeBankRepositoryProvider).claimExpiredSessionRefund(
            sessionId: session.id,
            learnerId: user.uid,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم استرداد عملة الوقت إلى محفظتك بنجاح لانتهاء المهلة 🔄')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر استرداد العملة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _showDisputeDialog(TimeBankSessionModel session) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('فتح نزاع واعتراض'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إذا لم يقم الزميل بتقديم الشرح أو لم يحضر، يمكنك فتح نزاع. ستبقى العملة محتجزة في الضمان ولن يتم تحريرها حتى يتم مراجعة الأمر يدوياً.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'سبب النزاع (مثال: لم يحضر الشارح)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('فتح النزاع', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);
    try {
      await ref.read(timeBankRepositoryProvider).openSessionDispute(
            sessionId: session.id,
            learnerId: user.uid,
            reason: controller.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم فتح النزاع بنجاح. العملة محتجزة في أمان الضمان 🛡️')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح النزاع: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final teacherName = session?.teacherName ?? 'الزميل الشارح';
    final teacherInitials = session?.teacherInitials ?? 'ع.خ';
    final courseName = session?.courseName ?? 'المادة الدراسية';
    final topic = session?.topic ?? 'موضوع الشرح';
    final duration = '${session?.durationMinutes ?? 60} دقيقة كاملة';
    final location = session?.location ?? 'مبنى الكلية';
    final escrowStatus = session?.escrowStatus ?? 'held';
    final isHeld = escrowStatus == 'held';
    final isReleased = escrowStatus == 'released_to_teacher';
    final isRefunded = escrowStatus == 'refunded_to_learner';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final hairline = isDark ? AppColors.darkHairline : AppColors.hairline;
    final onSurface = theme.colorScheme.onSurface;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final primaryContainer = isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_forward_ios_rounded, color: onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'تفاصيل الجلسة وتأكيدها 🎓',
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
              // Teacher Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: hairline),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: primaryContainer,
                      child: Text(teacherInitials, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$teacherName (الشارح)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onSurface)),
                          const SizedBox(height: 2),
                          Text('الفرقة الثانية • كلية الحاسبات والذكاء الاصطناعي', style: TextStyle(fontSize: 12, color: textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Status badge
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isReleased
                      ? primaryColor.withValues(alpha: 0.15)
                      : (isRefunded ? AppColors.error.withValues(alpha: 0.1) : AppColors.sage.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isReleased
                        ? primaryColor.withValues(alpha: 0.3)
                        : (isRefunded ? AppColors.error.withValues(alpha: 0.3) : AppColors.sage.withValues(alpha: 0.3)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isReleased
                          ? Icons.stars_rounded
                          : (isRefunded ? Icons.undo_rounded : Icons.lock_clock_rounded),
                      color: isReleased ? primaryColor : (isRefunded ? AppColors.error : AppColors.deepSage),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isReleased
                            ? 'تم إتمام الجلسة وإطلاق العملة بنجاح! تقييمك للشارح: ${session?.rating ?? 5} نجوم ⭐'
                            : (isRefunded
                                ? 'تم إلغاء هذه الجلسة واسترداد العملة إلى محفظتك.'
                                : 'الجلسة معلقة بالضمان (1 عملة محجوزة). بعد انتهاء الشرح، اضغط لتأكيد الإتمام وتقييم الزميل.'),
                        style: TextStyle(
                          fontSize: 13,
                          color: isReleased ? primaryColor : (isRefunded ? AppColors.error : AppColors.deepSage),
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
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: hairline),
                ),
                child: Column(
                  children: [
                    _RowItem('المادة', courseName),
                    Divider(height: 20, color: hairline),
                    _RowItem('الموضوع', topic),
                    Divider(height: 20, color: hairline),
                    _RowItem('المدة المقررة', duration),
                    Divider(height: 20, color: hairline),
                    _RowItem('المكان / طريقة اللقاء', session?.mode == 'online' ? 'أونلاين عن بُعد 💻' : location),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (session?.mode == 'online') ...[
                if (session?.meetingUrl != null && session!.meetingUrl!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.videocam_rounded, color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'رابط جلسة الشرح الأونلاين',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          session.meetingUrl!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: session.meetingUrl!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم نسخ رابط الاجتماع بنجاح 📋')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                          label: const Text('نسخ رابط الاجتماع', style: TextStyle(color: Colors.white, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'الجلسة أونلاين. سيقوم الشارح بإضافة رابط الاجتماع (Google Meet / Zoom) قبل موعد الجلسة.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
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
                    icon: const Icon(Icons.forum_outlined, color: AppColors.primary),
                    label: Text(
                      'محادثة لتنسيق اللقاء مع $teacherName 💬',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (session != null && session.status == 'disputed') ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.gavel_rounded, color: AppColors.error, size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'هذه الجلسة قيد النزاع بناءً على طلبك. عملتك محتجزة بأمان في الضمان ولن يتم تحريرها حتى تراجع الإدارة المشكلة.',
                          style: TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // أزرار التحكم بحالة الجلسة للمتعلم
              if (session != null && session.status == 'pending') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.pointsAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.pointsAmber.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.hourglass_top_rounded, color: AppColors.pointsAmber, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'الطلب بانتظار موافقة الزميل الشارح. عملتك محتجزة بأمان في الضمان.',
                          style: TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (session.createdAt != null &&
                    TimeBankPureLogic.canLearnerClaimExpiredRefund(
                      status: session.status,
                      escrowStatus: session.escrowStatus,
                      createdAt: session.createdAt!,
                      scheduledAt: session.scheduledAt,
                    )) ...[
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isCancelling ? null : () => _claimExpiredRefund(session),
                      icon: const Icon(Icons.undo_rounded, color: Colors.white),
                      label: Text(
                        _isCancelling ? 'جاري الاسترداد...' : 'استرداد العملة (انتهاء مهلة الرد) 🔄',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _isCancelling ? null : () => _cancelSession(session),
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                      label: Text(
                        _isCancelling ? 'جاري إلغاء الطلب...' : 'إلغاء الطلب واسترداد العملة فوراً',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ] else if (isHeld && session?.status != 'disputed') ...[
                if (session != null &&
                    session.status == 'confirmed' &&
                    session.teacherMarkedDoneAt != null) ...[
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _isCancelling ? null : () => _showDisputeDialog(session),
                      icon: const Icon(Icons.report_problem_outlined, color: AppColors.error),
                      label: const Text(
                        'فتح نزاع / الشارح لم يقدم الجلسة ⚠️',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/session-rating', extra: session),
                    icon: const Icon(Icons.verified_rounded, color: Colors.white),
                    label: const Text(
                      'أؤكد إتمام الجلسة وتقييم الزميل',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isCancelling ? null : () => session != null ? _cancelSession(session) : null,
                    icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                    label: Text(
                      _isCancelling ? 'جاري إلغاء الجلسة...' : 'إلغاء الجلسة',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    final isDark = theme.brightness == Brightness.dark;

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
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
