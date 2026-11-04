import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// شريط التنبيه عند فقدان الاتصال بالإنترنت (Offline Banner)
class OfflineBanner extends StatelessWidget {
  final String message;
  final bool isVisible;

  const OfflineBanner({
    super.key,
    this.message = 'أنت تعمل حالياً بدون اتصال. ستتم المزامنة تلقائياً عند عودة الإنترنت.',
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      color: AppColors.warning.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
