import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// مؤشر التحميل المتناسق مع هوية تطبيق «زَميل»
class AppLoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;

  const AppLoadingIndicator({
    super.key,
    this.message,
    this.size = 36.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = color ?? (isDark ? AppColors.darkPrimary : AppColors.primary);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: 3.0,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
