import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import '../../../../core/theme/app_colors.dart';

/// ويدجت ذكي لعرض صور الأسئلة والحلول سواء كانت روابط سحابية (https://)
/// أو بيانات مشفرة Base64 Data URL (data:image/...) مع دعم التحميل وحالات الخطأ والتكبير
class AppQuestionImage extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool enableZoomOnTap;

  const AppQuestionImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.enableZoomOnTap = false,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    if (cleanUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget content;

    if (cleanUrl.startsWith('data:image')) {
      try {
        final commaIndex = cleanUrl.indexOf(',');
        final base64Part = commaIndex != -1 ? cleanUrl.substring(commaIndex + 1) : cleanUrl;
        final bytes = base64Decode(base64Part.trim());
        content = Image.memory(
          bytes,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
        );
      } catch (e) {
        content = _buildErrorPlaceholder();
      }
    } else {
      content = Image.network(
        cleanUrl,
        height: height,
        width: width,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height ?? 160,
            width: width ?? double.infinity,
            color: Colors.black12,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                      : null,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
      );
    }

    if (borderRadius != null) {
      content = ClipRRect(borderRadius: borderRadius!, child: content);
    }

    if (enableZoomOnTap) {
      return GestureDetector(
        onTap: () => showFullImageDialog(context, cleanUrl),
        child: content,
      );
    }

    return content;
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      height: height ?? 120,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_rounded, color: Colors.grey, size: 28),
            SizedBox(height: 4),
            Text('تعذر تحميل الصورة', style: TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  /// فتح الصورة بالحجم الكامل في نافذة تكبير حرة
  static void showFullImageDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              maxScale: 4.0,
              minScale: 0.5,
              child: Center(
                child: AppQuestionImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const CircleAvatar(
                  backgroundColor: Colors.black54,
                  radius: 18,
                  child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
