// مطور 2
// فيجما: الترحيب - ذاكر وعلّم

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final hairlineColor = isDark ? AppColors.darkHairline : AppColors.hairline;
    final textPrimaryColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // الشعار والأيقونة الهندسية
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.hourglass_top_rounded,
                        size: 48,
                        color: AppColors.primary,
                      ),
                      Positioned(
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.pointsAmber,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'رصيد معرفي',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.deepSage,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Wordmark
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'زَميل • ذاكر وعلّم',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Headline
              const Text(
                'ذاكر بخطة، وعلّم زميلك، وتعلّم من غيرك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 12),

              // Supporting body
              const Text(
                'خطة مذاكرة ذكية، وبنك وقت يربطك بزملائك في كلية الحاسبات. مجاني بالكامل.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // Feature chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildChip(
                    label: 'نقاط وقت',
                    icon: Icons.monetization_on_outlined,
                    bgColor: AppColors.pointsAmber.withValues(alpha: 0.15),
                    textColor: const Color(0xFF664700),
                  ),
                  _buildChip(
                    label: 'شرح متبادل',
                    icon: Icons.groups_rounded,
                    bgColor: AppColors.sage.withValues(alpha: 0.2),
                    textColor: AppColors.deepSage,
                  ),
                  _buildChip(
                    label: 'خطة ذكية',
                    icon: Icons.auto_awesome_rounded,
                    bgColor: AppColors.primaryContainer.withValues(alpha: 0.5),
                    textColor: AppColors.primary,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Reciprocity card 1:1
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: hairlineColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'نظام بنك الساعات الأكاديمي',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'كل ساعة شرح تمنحك ساعة تعلّم مجانية',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.pointsAmber.withValues(alpha: isDark ? 0.25 : 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '1:1',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFFFD54F) : const Color(0xFF664700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Primary CTA: ابدأ الآن -> /signup
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/signup'),
                  icon: Icon(Icons.arrow_back_rounded, color: isDark ? AppColors.darkOnPrimary : AppColors.onPrimary, size: 20),
                  label: Text(
                    'ابدأ الآن',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkOnPrimary : AppColors.onPrimary,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Secondary Ghost Action: لدي حساب بالفعل -> /login
              TextButton(
                onPressed: () => context.push('/login'),
                child: Text(
                  'لدي حساب بالفعل',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Trust indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.verified_user_rounded, size: 14, color: AppColors.sage),
                  SizedBox(width: 6),
                  Text(
                    'منصة جامعية تعاونية موثوقة • كلية الحاسبات والذكاء الاصطناعي',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
