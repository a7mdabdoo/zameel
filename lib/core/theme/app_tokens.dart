import 'package:material_ui/material_ui.dart';
import 'app_colors.dart';

/// نظام الرموز اللونية والمعمارية المعتمدة لتطبيق «زميل»
class AppTokens extends ThemeExtension<AppTokens> {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textHigh;
  final Color textMedium;
  final Color textLow;
  final Color brand;
  final Color brandContainer;
  final Color onBrand;
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color danger;
  final Color dangerContainer;
  final Color coin;
  final Color onCoin;
  final Color scrim;

  // Course tags (exactly 6)
  final Color courseTeal;
  final Color courseSage;
  final Color courseSand;
  final Color courseClay;
  final Color courseSlate;
  final Color courseDustPlum;

  const AppTokens({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textHigh,
    required this.textMedium,
    required this.textLow,
    required this.brand,
    required this.brandContainer,
    required this.onBrand,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.coin,
    required this.onCoin,
    required this.scrim,
    required this.courseTeal,
    required this.courseSage,
    required this.courseSand,
    required this.courseClay,
    required this.courseSlate,
    required this.courseDustPlum,
  });

  List<Color> get courseColors => [
        courseTeal,
        courseSage,
        courseSand,
        courseClay,
        courseSlate,
        courseDustPlum,
      ];

  Color courseTint(Color courseColor, {double alpha = 0.15}) {
    return courseColor.withValues(alpha: alpha);
  }

  List<BoxShadow> get floatingShadow => [
        BoxShadow(
          color: scrim.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static const Color courseTealColor = AppColors.courseTeal;
  static const Color courseSageColor = AppColors.courseSage;
  static const Color courseSandColor = AppColors.courseSand;
  static const Color courseClayColor = AppColors.courseClay;
  static const Color courseSlateColor = AppColors.courseSlate;
  static const Color courseDustPlumColor = AppColors.courseDustPlum;

  // Light Palette
  static const AppTokens light = AppTokens(
    bg: AppColors.background, // F8FAFC
    surface: AppColors.surface, // FFFFFF
    surfaceAlt: AppColors.surfaceAlt, // F1F5F9
    border: AppColors.hairline, // E2E8F0
    textHigh: AppColors.textPrimary, // 0F172A (contrast > 16:1)
    textMedium: AppColors.textSecondary, // 475569 (contrast > 7:1)
    textLow: Color(0xFF5E6E82), // adjusted from 94A3B8 for WCAG AA >= 4.5:1 text contrast
    brand: AppColors.primary, // 1F6F6B (contrast > 5.4:1)
    brandContainer: AppColors.primaryContainer, // E0F2F1
    onBrand: AppColors.onPrimary, // FFFFFF
    success: Color(0xFF2E7D52), // adjusted from 3E8E63 for text contrast >= 4.5:1
    successContainer: Color(0xFFE8F5E9),
    warning: Color(0xFF9A6510), // adjusted from C98A2B for text contrast >= 4.5:1
    warningContainer: Color(0xFFFFF8E1),
    danger: Color(0xFFBA3D35), // adjusted from C4554D for text contrast >= 4.5:1
    dangerContainer: Color(0xFFFFEBEE),
    coin: AppColors.pointsAmber, // D9A441 (used only as fill, never text)
    onCoin: AppColors.textPrimary, // 0F172A (contrast on coin 7.94:1 >= 4.5:1)
    scrim: Color(0x80000000),
    courseTeal: AppColors.courseTeal,
    courseSage: AppColors.courseSage,
    courseSand: AppColors.courseSand,
    courseClay: AppColors.courseClay,
    courseSlate: AppColors.courseSlate,
    courseDustPlum: AppColors.courseDustPlum,
  );

  // Dark Palette
  static const AppTokens dark = AppTokens(
    bg: AppColors.darkBackground, // 0B131E
    surface: AppColors.darkSurface, // 15202B
    surfaceAlt: AppColors.darkSurfaceAlt, // 1E2D3D
    border: AppColors.darkHairline, // 223244
    textHigh: AppColors.darkTextPrimary, // F1F5F9 (contrast > 12:1)
    textMedium: AppColors.darkTextSecondary, // CBD5E1 (contrast > 9:1)
    textLow: AppColors.darkTextTertiary, // 94A3B8 (contrast on dark surfaces 5.5:1 to 7.3:1)
    brand: AppColors.darkPrimary, // 2DD4BF (contrast > 7.5:1)
    brandContainer: AppColors.darkPrimaryContainer, // 133938
    onBrand: AppColors.darkOnPrimary, // 0B131E (contrast > 10:1)
    success: Color(0xFF34D399), // contrast > 8:1
    successContainer: Color(0xFF133826),
    warning: Color(0xFFFBBF24), // contrast > 7:1
    warningContainer: Color(0xFF382A13),
    danger: Color(0xFFF87171), // contrast > 6:1
    dangerContainer: Color(0xFF3E1A18),
    coin: AppColors.pointsAmber, // D9A441
    onCoin: AppColors.darkOnPrimary, // 0B131E (contrast on coin 8.29:1 >= 4.5:1)
    scrim: Color(0xB3000000),
    courseTeal: AppColors.courseTeal,
    courseSage: AppColors.courseSage,
    courseSand: AppColors.courseSand,
    courseClay: AppColors.courseClay,
    courseSlate: AppColors.courseSlate,
    courseDustPlum: AppColors.courseDustPlum,
  );

  @override
  AppTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textHigh,
    Color? textMedium,
    Color? textLow,
    Color? brand,
    Color? brandContainer,
    Color? onBrand,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? danger,
    Color? dangerContainer,
    Color? coin,
    Color? onCoin,
    Color? scrim,
    Color? courseTeal,
    Color? courseSage,
    Color? courseSand,
    Color? courseClay,
    Color? courseSlate,
    Color? courseDustPlum,
  }) {
    return AppTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textHigh: textHigh ?? this.textHigh,
      textMedium: textMedium ?? this.textMedium,
      textLow: textLow ?? this.textLow,
      brand: brand ?? this.brand,
      brandContainer: brandContainer ?? this.brandContainer,
      onBrand: onBrand ?? this.onBrand,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      coin: coin ?? this.coin,
      onCoin: onCoin ?? this.onCoin,
      scrim: scrim ?? this.scrim,
      courseTeal: courseTeal ?? this.courseTeal,
      courseSage: courseSage ?? this.courseSage,
      courseSand: courseSand ?? this.courseSand,
      courseClay: courseClay ?? this.courseClay,
      courseSlate: courseSlate ?? this.courseSlate,
      courseDustPlum: courseDustPlum ?? this.courseDustPlum,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      bg: Color.lerp(bg, other.bg, t) ?? bg,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t) ?? surfaceAlt,
      border: Color.lerp(border, other.border, t) ?? border,
      textHigh: Color.lerp(textHigh, other.textHigh, t) ?? textHigh,
      textMedium: Color.lerp(textMedium, other.textMedium, t) ?? textMedium,
      textLow: Color.lerp(textLow, other.textLow, t) ?? textLow,
      brand: Color.lerp(brand, other.brand, t) ?? brand,
      brandContainer: Color.lerp(brandContainer, other.brandContainer, t) ?? brandContainer,
      onBrand: Color.lerp(onBrand, other.onBrand, t) ?? onBrand,
      success: Color.lerp(success, other.success, t) ?? success,
      successContainer: Color.lerp(successContainer, other.successContainer, t) ?? successContainer,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t) ?? warningContainer,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t) ?? dangerContainer,
      coin: Color.lerp(coin, other.coin, t) ?? coin,
      onCoin: Color.lerp(onCoin, other.onCoin, t) ?? onCoin,
      scrim: Color.lerp(scrim, other.scrim, t) ?? scrim,
      courseTeal: Color.lerp(courseTeal, other.courseTeal, t) ?? courseTeal,
      courseSage: Color.lerp(courseSage, other.courseSage, t) ?? courseSage,
      courseSand: Color.lerp(courseSand, other.courseSand, t) ?? courseSand,
      courseClay: Color.lerp(courseClay, other.courseClay, t) ?? courseClay,
      courseSlate: Color.lerp(courseSlate, other.courseSlate, t) ?? courseSlate,
      courseDustPlum: Color.lerp(courseDustPlum, other.courseDustPlum, t) ?? courseDustPlum,
    );
  }
}

/// مقياس الأشكال الموحد
class AppRadii {
  static const double control = 12.0;
  static const double card = 16.0;
  static const double sheet = 24.0;
  static const double chip = 999.0;
  static const double full = 999.0;

  static final BorderRadius controlRadius = BorderRadius.circular(control);
  static final BorderRadius cardRadius = BorderRadius.circular(card);
  static final BorderRadius sheetRadius = BorderRadius.circular(sheet);
  static final BorderRadius chipRadius = BorderRadius.circular(chip);
  static final BorderRadius fullRadius = BorderRadius.circular(full);

  static const Radius controlRadiusValue = Radius.circular(control);
  static const Radius cardRadiusValue = Radius.circular(card);
  static const Radius sheetRadiusValue = Radius.circular(sheet);
  static const Radius bubbleRadius = Radius.circular(card);
  static const Radius bubbleNipRadius = Radius.circular(4.0);

  static const BorderRadius sheetTopRadius = BorderRadius.vertical(top: Radius.circular(sheet));
  static const BorderRadius cardTopRadius = BorderRadius.vertical(top: Radius.circular(card));
}

/// مقياس المسافات الموحد
class AppSpacing {
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
}

extension BuildContextTokens on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ??
      (Theme.of(this).brightness == Brightness.dark ? AppTokens.dark : AppTokens.light);
}
