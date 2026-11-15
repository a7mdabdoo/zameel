// مطور 1
// فيجما: تفاصيل الجلسة - عرض الشارح (الربط الحي بالضمان والفايربيز)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/app_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_service.dart';
import '../../timebank/data/timebank_repository.dart';
import 'widgets/session_chat_sheet.dart';

class SessionDetailsTeacherScreen extends ConsumerStatefulWidget {
  final TimeBankSessionModel? session;
  const SessionDetailsTeacherScreen({super.key, this.session});

  @override
  ConsumerState<SessionDetailsTeacherScreen> createState() => _SessionDetailsTeacherScreenState();
}

class _SessionDetailsTeacherScreenState extends ConsumerState<SessionDetailsTeacherScreen> {
  bool _isCancelling = false;

  Future<void> _cancelSession(TimeBankSessionModel session) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الجلسة من قِبل الشارح'),
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
            reason: 'إلغاء من قِبل الشارح',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء الجلسة واسترداد العملة للمتعلم بنجاح 🔄')),
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
          'تفاصيل الجلسة (أنت الشارح) 👨‍🏫',
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
                  borderRadius: BorderRadius.circular(18),
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
                      ? primaryColor.withValues(alpha: 0.15)
                      : (isRefunded ? AppColors.error.withValues(alpha: 0.1) : AppColors.pointsAmber.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isReleased
                        ? primaryColor.withValues(alpha: 0.3)
                        : (isRefunded ? AppColors.error.withValues(alpha: 0.3) : AppColors.pointsAmber.withValues(alpha: 0.3)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isReleased
                          ? Icons.check_circle_rounded
                          : (isRefunded ? Icons.info_outline_rounded : Icons.stars_rounded),
                      color: isReleased ? primaryColor : (isRefunded ? AppColors.error : AppColors.pointsAmber),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isReleased
                            ? 'تم إتمام الشرح وتحرير عملة الوقت إلى محفظتك بنجاح! تقييم الزميل لك: ${session?.rating ?? 5} نجوم ⭐'
                            : (isRefunded
                                ? 'تم إلغاء هذه الجلسة واسترداد العملة للمتعلم.'
                                : 'الجلسة مؤكدة ومحجوزة في الضمان. بعد انتهاء الشرح وتأكيد المتعلم، ستضاف 1 عملة وقت إلى محفظتك فوراً.'),
                        style: TextStyle(
                          fontSize: 13,
                          color: isReleased ? primaryColor : (isRefunded ? AppColors.error : (isDark ? const Color(0xFFFFD54F) : const Color(0xFF664700))),
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
                    _RowItem('الموضوع المطلوب', topic),
                    Divider(height: 20, color: hairline),
                    _RowItem('المدة المقررة', duration),
                    Divider(height: 20, color: hairline),
                    _RowItem('المكان / طريقة اللقاء', location.contains('أونلاين') || location.contains('http') || location.contains('zoom') || location.contains('meet') ? 'أونلاين (Zoom / Google Meet) 💻' : location),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (location.contains('http') || location.contains('meet') || location.contains('zoom') || location.contains('أونلاين')) ...[
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
                        location.replaceAll('أونلاين:', '').trim(),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: location.replaceAll('أونلاين:', '').trim()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نسخ رابط الاجتماع (Zoom / Meet) بنجاح 📋')),
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
                const SizedBox(height: 14),
              ] else
                const SizedBox(height: 8),

              // Chat Button
              if (session != null) ...[
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => SessionChatSheet.show(context, session, learnerName),
                    icon: const Icon(Icons.forum_outlined, color: AppColors.primary),
                    label: Text(
                      'محادثة لتنسيق اللقاء مع $learnerName 💬',
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

              if (isHeld) ...[
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isCancelling ? null : () => session != null ? _cancelSession(session) : null,
                    icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                    label: Text(
                      _isCancelling ? 'جاري إلغاء الجلسة...' : 'إلغاء الجلسة واعتذار للمتعلم',
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
