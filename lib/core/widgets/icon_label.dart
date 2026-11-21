import 'package:material_ui/material_ui.dart';

/// ويدجت موحدة لعرض أيقونة بجوار نص مع مراعاة اتجاه اللغة العربية والمسافات المتناسقة
class IconLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextStyle? style;
  final Color? iconColor;
  final double iconSize;
  final double spacing;
  final MainAxisSize mainAxisSize;

  const IconLabel({
    super.key,
    required this.icon,
    required this.label,
    this.style,
    this.iconColor,
    this.iconSize = 16.0,
    this.spacing = 6.0,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = iconColor ?? style?.color ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: iconSize,
          color: effectiveColor,
        ),
        SizedBox(width: spacing),
        Flexible(
          child: Text(
            label,
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
