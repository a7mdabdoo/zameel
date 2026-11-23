import 'package:material_ui/material_ui.dart';

/// الشعار المعتمد لتطبيق «زميل»
/// يعرض أيقونة الهوية البصرية الرسمية المعتمدة للمنظومة بدقة عالية ووضوح كامل.
class ZameelLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const ZameelLogo({
    super.key,
    this.size = 56.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/brand_symbol.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
    );
  }
}
