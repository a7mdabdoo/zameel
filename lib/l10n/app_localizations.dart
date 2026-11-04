import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ar')];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'زَميل'**
  String get appName;

  /// No description provided for @appSlogan.
  ///
  /// In ar, this message translates to:
  /// **'ذاكر بخطة، وعلّم زميلك، وتعلّم من غيرك'**
  String get appSlogan;

  /// No description provided for @appSubSlogan.
  ///
  /// In ar, this message translates to:
  /// **'خطة مذاكرة ذكية، وبنك وقت يربطك بزملائك في كلية الحاسبات. مجاني بالكامل.'**
  String get appSubSlogan;

  /// No description provided for @startNow.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الآن'**
  String get startNow;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In ar, this message translates to:
  /// **'لدي حساب بالفعل'**
  String get alreadyHaveAccount;

  /// No description provided for @welcomeBonusTitle.
  ///
  /// In ar, this message translates to:
  /// **'رصيد معرفي'**
  String get welcomeBonusTitle;

  /// No description provided for @timeBankConcept.
  ///
  /// In ar, this message translates to:
  /// **'نظام بنك الساعات الأكاديمي'**
  String get timeBankConcept;

  /// No description provided for @timeBankSubConcept.
  ///
  /// In ar, this message translates to:
  /// **'كل ساعة شرح تمنحك ساعة تعلّم مجانية'**
  String get timeBankSubConcept;

  /// No description provided for @ratioOneToOne.
  ///
  /// In ar, this message translates to:
  /// **'1:1'**
  String get ratioOneToOne;

  /// No description provided for @loginTitle.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً بعودتك 👋'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سجّل دخولك للوصول إلى خطتك الدراسية وجلسات بنك الوقت'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In ar, this message translates to:
  /// **'البريد الجامعي أو الإلكتروني'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In ar, this message translates to:
  /// **'student@fci.edu.eg'**
  String get emailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In ar, this message translates to:
  /// **'••••••••'**
  String get passwordHint;

  /// No description provided for @forgotPassword.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get forgotPassword;

  /// No description provided for @loginAction.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get loginAction;

  /// No description provided for @noAccount.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟'**
  String get noAccount;

  /// No description provided for @createAccountAction.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ حساباً الآن'**
  String get createAccountAction;

  /// No description provided for @signupTitle.
  ///
  /// In ar, this message translates to:
  /// **'انضم إلى زَميل 🎓'**
  String get signupTitle;

  /// No description provided for @signupSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ حسابك واحصل على نقطتي وقت ترحيبيتين لبدء التعلّم التشاركي'**
  String get signupSubtitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'الاسم بالكامل'**
  String get fullNameLabel;

  /// No description provided for @fullNameHint.
  ///
  /// In ar, this message translates to:
  /// **'أحمد محمود'**
  String get fullNameHint;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور'**
  String get confirmPasswordLabel;

  /// No description provided for @signupSubmit.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الحساب ومتابعة التهيئة'**
  String get signupSubmit;

  /// No description provided for @onboardingStep1.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة 1 من 3'**
  String get onboardingStep1;

  /// No description provided for @onboardingStep2.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة 2 من 3'**
  String get onboardingStep2;

  /// No description provided for @onboardingStep3.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة 3 من 3'**
  String get onboardingStep3;

  /// No description provided for @academicDataTitle.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك الأكاديمية 🏫'**
  String get academicDataTitle;

  /// No description provided for @academicDataSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'لتخصيص المواد ومطابقة مواعيدك مع زملاء دفعتك'**
  String get academicDataSubtitle;

  /// No description provided for @facultyLabel.
  ///
  /// In ar, this message translates to:
  /// **'الكلية'**
  String get facultyLabel;

  /// No description provided for @yearLabel.
  ///
  /// In ar, this message translates to:
  /// **'السنة الدراسية'**
  String get yearLabel;

  /// No description provided for @departmentLabel.
  ///
  /// In ar, this message translates to:
  /// **'القسم الأكاديمي'**
  String get departmentLabel;

  /// No description provided for @nextCourses.
  ///
  /// In ar, this message translates to:
  /// **'التالي: اختيار المواد'**
  String get nextCourses;

  /// No description provided for @selectCoursesTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر مواد الفصل الدراسي 📚'**
  String get selectCoursesTitle;

  /// No description provided for @selectCoursesSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديد مواد مقترحة لطلاب الفرقة الثانية'**
  String get selectCoursesSubtitle;

  /// No description provided for @nextRatings.
  ///
  /// In ar, this message translates to:
  /// **'التالي: تقييم مستواك'**
  String get nextRatings;

  /// No description provided for @rateLevelTitle.
  ///
  /// In ar, this message translates to:
  /// **'قيّم مستواك في المواد 🎯'**
  String get rateLevelTitle;

  /// No description provided for @rateLevelSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'لتوجيه خوارزمية التوافق الذكي لبنك الوقت بين المتعلمين والشارحين'**
  String get rateLevelSubtitle;

  /// No description provided for @levelNeedHelp.
  ///
  /// In ar, this message translates to:
  /// **'أحتاج مساعدة'**
  String get levelNeedHelp;

  /// No description provided for @levelMedium.
  ///
  /// In ar, this message translates to:
  /// **'متوسط'**
  String get levelMedium;

  /// No description provided for @levelReadyToTeach.
  ///
  /// In ar, this message translates to:
  /// **'مستعد للشرح'**
  String get levelReadyToTeach;

  /// No description provided for @startJourney.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ رحلتك في زَميل'**
  String get startJourney;

  /// No description provided for @navToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get navToday;

  /// No description provided for @navPlan.
  ///
  /// In ar, this message translates to:
  /// **'الخطة'**
  String get navPlan;

  /// No description provided for @navTimeBank.
  ///
  /// In ar, this message translates to:
  /// **'بنك الوقت'**
  String get navTimeBank;

  /// No description provided for @navWallet.
  ///
  /// In ar, this message translates to:
  /// **'المحفظة'**
  String get navWallet;

  /// No description provided for @navProfile.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get navProfile;

  /// No description provided for @goodMorning.
  ///
  /// In ar, this message translates to:
  /// **'صباح الخير يا {name} 👋'**
  String goodMorning(String name);

  /// No description provided for @timeCoinsChip.
  ///
  /// In ar, this message translates to:
  /// **'{count} نقاط وقت'**
  String timeCoinsChip(int count);

  /// No description provided for @nextUpCardTitle.
  ///
  /// In ar, this message translates to:
  /// **'جلسة تركيز فردية'**
  String get nextUpCardTitle;

  /// No description provided for @nextUpBadge.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get nextUpBadge;

  /// No description provided for @todayTimelineTitle.
  ///
  /// In ar, this message translates to:
  /// **'جدول اليوم ({count} عناصر)'**
  String todayTimelineTitle(int count);

  /// No description provided for @weeklyGoalRate.
  ///
  /// In ar, this message translates to:
  /// **'معدل إنجاز الأسبوع'**
  String get weeklyGoalRate;

  /// No description provided for @completedSessionsCount.
  ///
  /// In ar, this message translates to:
  /// **'أنجزت {done} من {total} جلسات هذا الأسبوع'**
  String completedSessionsCount(int done, int total);

  /// No description provided for @emptyStateTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عناصر حالياً'**
  String get emptyStateTitle;

  /// No description provided for @emptyStateSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر العناصر هنا فور إضافتها أو تحديث خطتك'**
  String get emptyStateSubtitle;

  /// No description provided for @errorStateTitle.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع'**
  String get errorStateTitle;

  /// No description provided for @errorStateSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحميل البيانات، يرجى التحقق من اتصالك والمحاولة مجدداً'**
  String get errorStateSubtitle;

  /// No description provided for @retryAction.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retryAction;

  /// No description provided for @offlineBanner.
  ///
  /// In ar, this message translates to:
  /// **'أنت في وضع عدم الاتصال • البيانات المعروضة مخزنة محلياً'**
  String get offlineBanner;

  /// No description provided for @loadingText.
  ///
  /// In ar, this message translates to:
  /// **'جاري التحميل...'**
  String get loadingText;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
