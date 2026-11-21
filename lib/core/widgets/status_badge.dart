import 'package:material_ui/material_ui.dart';

enum StatusBadgeType {
  pending,
  confirmed,
  completed,
  cancelled,
  expired,
  rejected,
  info,
}

/// شارة حالة موحدة واحترافية بدون إيموجيز مع أيقونات Material دائرية
class StatusBadge extends StatelessWidget {
  final String? status;
  final String? customLabel;
  final IconData? customIcon;
  final StatusBadgeType? type;
  final double fontSize;
  final double iconSize;
  final EdgeInsetsGeometry padding;

  const StatusBadge({
    super.key,
    this.status,
    this.customLabel,
    this.customIcon,
    this.type,
    this.fontSize = 11.5,
    this.iconSize = 14.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  factory StatusBadge.fromStatus(
    String status, {
    Key? key,
    double fontSize = 11.5,
    double iconSize = 14.0,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  }) {
    return StatusBadge(
      key: key,
      status: status,
      fontSize: fontSize,
      iconSize: iconSize,
      padding: padding,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedType = _resolveType();
    final config = _getConfig(resolvedType, isDark);

    final text = customLabel ?? config.label;
    final icon = customIcon ?? config.icon;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: config.textColor,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: config.textColor,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  StatusBadgeType _resolveType() {
    if (type != null) return type!;
    final s = (status ?? '').toLowerCase().trim();
    if (s == 'pending' || s == 'waiting') return StatusBadgeType.pending;
    if (s == 'confirmed' || s == 'held' || s == 'active') return StatusBadgeType.confirmed;
    if (s == 'completed' || s == 'completed_auto' || s == 'released_to_teacher') return StatusBadgeType.completed;
    if (s == 'rejected') return StatusBadgeType.rejected;
    if (s == 'expired' || s == 'cancelled_expired') return StatusBadgeType.expired;
    if (s.contains('cancel') || s == 'refunded_to_learner') return StatusBadgeType.cancelled;
    return StatusBadgeType.info;
  }

  _BadgeConfig _getConfig(StatusBadgeType t, bool isDark) {
    switch (t) {
      case StatusBadgeType.pending:
        return _BadgeConfig(
          label: 'بانتظار الموافقة',
          icon: Icons.schedule_rounded,
          textColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
          backgroundColor: isDark ? const Color(0xFF2E2211) : const Color(0xFFFEF3C7),
          borderColor: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A),
        );
      case StatusBadgeType.confirmed:
        return _BadgeConfig(
          label: 'مؤكدة',
          icon: Icons.check_circle_outline_rounded,
          textColor: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
          backgroundColor: isDark ? const Color(0xFF132C2A) : const Color(0xFFCCFBF1),
          borderColor: isDark ? const Color(0xFF115E59) : const Color(0xFF99F6E4),
        );
      case StatusBadgeType.completed:
        return _BadgeConfig(
          label: 'مكتملة',
          icon: Icons.task_alt_rounded,
          textColor: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
          backgroundColor: isDark ? const Color(0xFF112E23) : const Color(0xFFD1FAE5),
          borderColor: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0),
        );
      case StatusBadgeType.cancelled:
        return _BadgeConfig(
          label: 'ملغاة',
          icon: Icons.cancel_outlined,
          textColor: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
          backgroundColor: isDark ? const Color(0xFF2F1818) : const Color(0xFFFEE2E2),
          borderColor: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
        );
      case StatusBadgeType.expired:
        return _BadgeConfig(
          label: 'منتهية',
          icon: Icons.timer_off_outlined,
          textColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        );
      case StatusBadgeType.rejected:
        return _BadgeConfig(
          label: 'معتذر عنها',
          icon: Icons.block_rounded,
          textColor: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
          backgroundColor: isDark ? const Color(0xFF2F1818) : const Color(0xFFFEE2E2),
          borderColor: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
        );
      case StatusBadgeType.info:
        return _BadgeConfig(
          label: 'معلومات',
          icon: Icons.info_outline_rounded,
          textColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
          backgroundColor: isDark ? const Color(0xFF172554) : const Color(0xFFDBEAFE),
          borderColor: isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE),
        );
    }
  }
}

class _BadgeConfig {
  final String label;
  final IconData icon;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;

  _BadgeConfig({
    required this.label,
    required this.icon,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
  });
}
