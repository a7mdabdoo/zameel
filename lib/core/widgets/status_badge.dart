import 'package:material_ui/material_ui.dart';
import '../theme/app_tokens.dart';

enum StatusBadgeType {
  pending,
  confirmed,
  completed,
  cancelled,
  expired,
  rejected,
  info,
}

/// شارة حالة موحدة واحترافية بدون إيموجيز معتمدة على الرموز الدلالية (Tokens)
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
    final tokens = context.tokens;
    final resolvedType = _resolveType();
    final config = _getConfig(resolvedType, tokens);

    final text = customLabel ?? config.label;
    final icon = customIcon ?? config.icon;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: AppRadii.chipRadius,
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

  _BadgeConfig _getConfig(StatusBadgeType t, AppTokens tokens) {
    switch (t) {
      case StatusBadgeType.pending:
        return _BadgeConfig(
          label: 'بانتظار الموافقة',
          icon: Icons.schedule_rounded,
          textColor: tokens.warning,
          backgroundColor: tokens.warningContainer,
          borderColor: tokens.warning.withValues(alpha: 0.3),
        );
      case StatusBadgeType.confirmed:
        return _BadgeConfig(
          label: 'مؤكدة',
          icon: Icons.check_circle_outline_rounded,
          textColor: tokens.brand,
          backgroundColor: tokens.brandContainer,
          borderColor: tokens.brand.withValues(alpha: 0.3),
        );
      case StatusBadgeType.completed:
        return _BadgeConfig(
          label: 'مكتملة',
          icon: Icons.task_alt_rounded,
          textColor: tokens.success,
          backgroundColor: tokens.successContainer,
          borderColor: tokens.success.withValues(alpha: 0.3),
        );
      case StatusBadgeType.cancelled:
        return _BadgeConfig(
          label: 'ملغاة',
          icon: Icons.cancel_outlined,
          textColor: tokens.danger,
          backgroundColor: tokens.dangerContainer,
          borderColor: tokens.danger.withValues(alpha: 0.3),
        );
      case StatusBadgeType.expired:
        return _BadgeConfig(
          label: 'منتهية',
          icon: Icons.timer_off_outlined,
          textColor: tokens.textLow,
          backgroundColor: tokens.surfaceAlt,
          borderColor: tokens.border,
        );
      case StatusBadgeType.rejected:
        return _BadgeConfig(
          label: 'معتذر عنها',
          icon: Icons.block_rounded,
          textColor: tokens.danger,
          backgroundColor: tokens.dangerContainer,
          borderColor: tokens.danger.withValues(alpha: 0.3),
        );
      case StatusBadgeType.info:
        return _BadgeConfig(
          label: 'معلومات',
          icon: Icons.info_outline_rounded,
          textColor: tokens.textMedium,
          backgroundColor: tokens.surfaceAlt,
          borderColor: tokens.border,
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
