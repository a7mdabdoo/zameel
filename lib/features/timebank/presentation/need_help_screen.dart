// مطور 3
// فيجما: بنك الوقت: طلب مساعدة

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_tokens.dart';

class NeedHelpScreen extends StatefulWidget {
  const NeedHelpScreen({super.key});

  @override
  State<NeedHelpScreen> createState() => _NeedHelpScreenState();
}

class _NeedHelpScreenState extends State<NeedHelpScreen> {
  CourseSeed _selectedCourse = AppConstants.seedCourses[3]; // الجبر الخطي
  final _topicController = TextEditingController(text: 'الفضاءات المتجهة والتحويلات الخطية');
  final String _preferredSlot = 'اليوم بعد الظهر (بين 1:00 م و 3:00 م)';

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final cardColor = tokens.surface;
    final hairline = tokens.border;
    final onSurface = theme.colorScheme.onSurface;

    final effectiveCourse = AppConstants.seedCourses.firstWhere(
      (c) => c.id == _selectedCourse.id,
      orElse: () => AppConstants.seedCourses.first,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_forward_ios_rounded, color: onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'طلب مساعدة من زميل',
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
              // Info Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.brandContainer.withValues(alpha: 0.4),
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: tokens.brand.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: tokens.brand, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'جلسة الشرح تكلف 1 عملة وقت فقط. بعد انتهاء الجلسة يتم تحويلها للزميل الشارح تلقائياً.',
                        style: TextStyle(fontSize: 12, color: tokens.brand, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Course
              Text('المادة التي تحتاج مساعدة فيها', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onSurface)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: AppRadii.controlRadius,
                  border: Border.all(color: hairline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<CourseSeed>(
                    value: effectiveCourse,
                    isExpanded: true,
                    dropdownColor: cardColor,
                    items: AppConstants.seedCourses.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(c.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onSurface)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCourse = val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Topic description
              Text('ما الجزء أو الموضوع المحدد؟', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onSurface)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _topicController,
                maxLines: 3,
                style: TextStyle(color: onSurface),
                decoration: InputDecoration(
                  hintText: 'اكتب ما تواجه صعوبة فيه (مثال: التحويلات الخطية والمصفوفات)',
                  hintStyle: TextStyle(color: tokens.textLow),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide(color: hairline)),
                  enabledBorder: OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide(color: hairline)),
                ),
              ),

              const SizedBox(height: 20),

              // Preferred time
              Text('الوقت المفضل لك', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onSurface)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: AppRadii.controlRadius,
                  border: Border.all(color: hairline),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, color: tokens.textMedium, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_preferredSlot, style: TextStyle(fontSize: 13, color: onSurface)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Search CTA -> /candidates
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/candidates', extra: _selectedCourse),
                  icon: Icon(Icons.search_rounded, color: Colors.white),
                  label: Text(
                    'ابحث عن زميل متاح',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brand,
                    shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}