import 'package:material_ui/material_ui.dart';
import '../theme/app_tokens.dart';

/// الشعار الهندسي الموحد لتطبيق «زميل»
/// مونوجرام حرف «ز» من قوسين هندسيين متشابكين يرمزان لتبادل المعرفة والتعلّم التشاركي.
class ZameelLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const ZameelLogo({
    super.key,
    this.size = 48.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.tokens.brand;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _ZameelLogoPainter(color: effectiveColor),
      ),
    );
  }
}

class _ZameelLogoPainter extends CustomPainter {
  final Color color;

  const _ZameelLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 512.0;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 48.0 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // النقطة الهندسية (The Knowledge Nuqta)
    final dotCenter = Offset(348.0 * scale, 100.0 * scale);
    final dotRadius = 32.0 * scale;
    canvas.drawCircle(dotCenter, dotRadius, fillPaint);

    // القوس الأول: الشارح (Peer 1 Arc)
    final path1 = Path()
      ..moveTo(372.0 * scale, 176.0 * scale)
      ..cubicTo(
        340.0 * scale,
        176.0 * scale,
        260.0 * scale,
        216.0 * scale,
        236.0 * scale,
        280.0 * scale,
      )
      ..cubicTo(
        216.0 * scale,
        332.0 * scale,
        230.0 * scale,
        380.0 * scale,
        264.0 * scale,
        404.0 * scale,
      );
    canvas.drawPath(path1, strokePaint);

    // القوس الثاني المتشابك: المتعلّم وامتداد ذيل الزاي (Peer 2 Arc)
    final path2 = Path()
      ..moveTo(308.0 * scale, 244.0 * scale)
      ..cubicTo(
        280.0 * scale,
        290.0 * scale,
        240.0 * scale,
        376.0 * scale,
        140.0 * scale,
        388.0 * scale,
      )
      ..cubicTo(
        112.0 * scale,
        391.0 * scale,
        92.0 * scale,
        380.0 * scale,
        80.0 * scale,
        364.0 * scale,
      );
    canvas.drawPath(path2, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ZameelLogoPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
