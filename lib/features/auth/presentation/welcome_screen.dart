// مطور 2
// فيجما: الترحيب - ذاكر وعلّم

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final surfaceColor = tokens.surface;
    final hairlineColor = tokens.border;
    final textPrimaryColor = tokens.textHigh;
    final textSecondaryColor = tokens.textMedium;
    final primaryColor = tokens.brand;

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
                    color: tokens.brandContainer,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.1),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.hourglass_top_rounded,
                        size: 48,
                        color: primaryColor,
                      ),
                      Positioned(
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tokens.surfaceAlt,
                            borderRadius: AppRadii.chipRadius,
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
                                decoration: BoxDecoration(
                                  color: tokens.coin,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'رصيد معرفي',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.brand,
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
                  color: tokens.brandContainer,
                  borderRadius: AppRadii.chipRadius,
                ),
                child: Text(
                  'زَميل • ذاكر وعلّم',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Headline
              Text(
                'ذاكر بخطة، وعلّم زميلك، وتعلّم من غيرك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 12),

              // Supporting body
              Text(
                'خطة مذاكرة ذكية، وبنك وقت يربطك بزملائك في كلية الحاسبات. مجاني بالكامل.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondaryColor,
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
                    bgColor: tokens.warningContainer,
                    textColor: tokens.warning,
                  ),
                  _buildChip(
                    label: 'شرح متبادل',
                    icon: Icons.groups_rounded,
                    bgColor: tokens.successContainer,
                    textColor: tokens.success,
                  ),
                  _buildChip(
                    label: 'خطة ذكية',
                    icon: Icons.auto_awesome_rounded,
                    bgColor: tokens.brandContainer,
                    textColor: tokens.brand,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Reciprocity card 1:1
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: hairlineColor),
                  boxShadow: tokens.floatingShadow,
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
                        color: tokens.warningContainer,
                        borderRadius: AppRadii.controlRadius,
                      ),
                      child: Text(
                        '1:1',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: tokens.warning,
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
                  icon: Icon(Icons.arrow_back_rounded, color: tokens.onBrand, size: 20),
                  label: Text(
                    'ابدأ الآن',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: tokens.onBrand,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadii.cardRadius,
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
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    size: 14,
                    color: tokens.brand,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'منصة جامعية تعاونية موثوقة • كلية الحاسبات والذكاء الاصطناعي',
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.textLow,
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
        borderRadius: AppRadii.chipRadius,
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
