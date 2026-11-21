import 'package:material_ui/material_ui.dart';
import '../theme/app_tokens.dart';

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
    final tokens = context.tokens;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      color: tokens.warningContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 18,
            color: tokens.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: tokens.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
