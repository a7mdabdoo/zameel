import 'package:material_ui/material_ui.dart';
import 'app_tokens.dart';

/// نظام الثيم المعتمد لـ «زميل» والمبني بنسبة 100% على الرموز الدلالية (Tokens)
class AppTheme {
  static const String fontFamily = 'IBMPlexSansArabic';

  static ThemeData light() => _buildTheme(AppTokens.light, Brightness.light);
  static ThemeData dark() => _buildTheme(AppTokens.dark, Brightness.dark);

  static ThemeData _buildTheme(AppTokens tokens, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final baseTextTheme = TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: tokens.textHigh,
        height: 1.3,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: tokens.textHigh,
        height: 1.3,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: tokens.textHigh,
        height: 1.4,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: tokens.textHigh,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: tokens.textHigh,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: tokens.textHigh,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.normal,
        color: tokens.textHigh,
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13.5,
        fontWeight: FontWeight.normal,
        color: tokens.textMedium,
        height: 1.6,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: tokens.textLow,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: tokens.textHigh,
        height: 1.3,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: tokens.textMedium,
        height: 1.3,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: tokens.textLow,
        height: 1.3,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: brightness,
      scaffoldBackgroundColor: tokens.bg,
      extensions: [tokens],
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: tokens.brand,
              onPrimary: tokens.onBrand,
              primaryContainer: tokens.brandContainer,
              surface: tokens.surface,
              onSurface: tokens.textHigh,
              onSurfaceVariant: tokens.textMedium,
              outline: tokens.border,
              error: tokens.danger,
              errorContainer: tokens.dangerContainer,
            )
          : ColorScheme.light(
              primary: tokens.brand,
              onPrimary: tokens.onBrand,
              primaryContainer: tokens.brandContainer,
              surface: tokens.surface,
              onSurface: tokens.textHigh,
              onSurfaceVariant: tokens.textMedium,
              outline: tokens.border,
              error: tokens.danger,
              errorContainer: tokens.dangerContainer,
            ),
      textTheme: baseTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.surface,
        foregroundColor: tokens.textHigh,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: tokens.textHigh),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: tokens.textHigh,
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: BorderSide(color: tokens.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: tokens.border,
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        modalBackgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: BorderSide(color: tokens.border, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.surfaceAlt,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: tokens.textHigh,
          fontSize: 13,
          height: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.controlRadius,
          side: BorderSide(color: tokens.border, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.surfaceAlt,
        side: BorderSide(color: tokens.border, width: 1),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.chipRadius),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: tokens.textHigh,
          fontSize: 12,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.brand;
          }
          return tokens.textLow;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.brandContainer;
          }
          return tokens.surfaceAlt;
        }),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: tokens.textHigh,
        iconColor: tokens.textMedium,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.brand,
          foregroundColor: tokens.onBrand,
          minimumSize: const Size(64, 44),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.brand,
          foregroundColor: tokens.onBrand,
          minimumSize: const Size(64, 44),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.brand,
          minimumSize: const Size(64, 44),
          elevation: 0,
          side: BorderSide(color: tokens.brand, width: 1),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.brand,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surface,
        indicatorColor: tokens.brandContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: tokens.brand);
          }
          return IconThemeData(color: tokens.textMedium);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: tokens.brand,
            );
          }
          return TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            color: tokens.textMedium,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: AppRadii.controlRadius,
          borderSide: BorderSide(color: tokens.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.controlRadius,
          borderSide: BorderSide(color: tokens.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.controlRadius,
          borderSide: BorderSide(color: tokens.brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.controlRadius,
          borderSide: BorderSide(color: tokens.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.controlRadius,
          borderSide: BorderSide(color: tokens.danger, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}