// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'زَميل';

  @override
  String get appSlogan => 'ذاكر بخطة، وعلّم زميلك، وتعلّم من غيرك';

  @override
  String get appSubSlogan =>
      'خطة مذاكرة ذكية، وبنك وقت يربطك بزملائك في كلية الحاسبات. مجاني بالكامل.';

  @override
  String get startNow => 'ابدأ الآن';

  @override
  String get alreadyHaveAccount => 'لدي حساب بالفعل';

  @override
  String get welcomeBonusTitle => 'رصيد معرفي';

  @override
  String get timeBankConcept => 'نظام بنك الساعات الأكاديمي';

  @override
  String get timeBankSubConcept => 'كل ساعة شرح تمنحك ساعة تعلّم مجانية';

  @override
  String get ratioOneToOne => '1:1';

  @override
  String get loginTitle => 'مرحباً بعودتك 👋';

  @override
  String get loginSubtitle =>
      'سجّل دخولك للوصول إلى خطتك الدراسية وجلسات بنك الوقت';

  @override
  String get emailLabel => 'البريد الجامعي أو الإلكتروني';

  @override
  String get emailHint => 'student@fci.edu.eg';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get passwordHint => '••••••••';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get loginAction => 'تسجيل الدخول';

  @override
  String get noAccount => 'ليس لديك حساب؟';

  @override
  String get createAccountAction => 'أنشئ حساباً الآن';

  @override
  String get signupTitle => 'انضم إلى زَميل 🎓';

  @override
  String get signupSubtitle =>
      'أنشئ حسابك واحصل على نقطتي وقت ترحيبيتين لبدء التعلّم التشاركي';

  @override
  String get fullNameLabel => 'الاسم بالكامل';

  @override
  String get fullNameHint => 'أحمد محمود';

  @override
  String get confirmPasswordLabel => 'تأكيد كلمة المرور';

  @override
  String get signupSubmit => 'إنشاء الحساب ومتابعة التهيئة';

  @override
  String get onboardingStep1 => 'الخطوة 1 من 3';

  @override
  String get onboardingStep2 => 'الخطوة 2 من 3';

  @override
  String get onboardingStep3 => 'الخطوة 3 من 3';

  @override
  String get academicDataTitle => 'بياناتك الأكاديمية 🏫';

  @override
  String get academicDataSubtitle =>
      'لتخصيص المواد ومطابقة مواعيدك مع زملاء دفعتك';

  @override
  String get facultyLabel => 'الكلية';

  @override
  String get yearLabel => 'السنة الدراسية';

  @override
  String get departmentLabel => 'القسم الأكاديمي';

  @override
  String get nextCourses => 'التالي: اختيار المواد';

  @override
  String get selectCoursesTitle => 'اختر مواد الفصل الدراسي 📚';

  @override
  String get selectCoursesSubtitle =>
      'تم تحديد مواد مقترحة لطلاب الفرقة الثانية';

  @override
  String get nextRatings => 'التالي: تقييم مستواك';

  @override
  String get rateLevelTitle => 'قيّم مستواك في المواد 🎯';

  @override
  String get rateLevelSubtitle =>
      'لتوجيه خوارزمية التوافق الذكي لبنك الوقت بين المتعلمين والشارحين';

  @override
  String get levelNeedHelp => 'أحتاج مساعدة';

  @override
  String get levelMedium => 'متوسط';

  @override
  String get levelReadyToTeach => 'مستعد للشرح';

  @override
  String get startJourney => 'ابدأ رحلتك في زَميل';

  @override
  String get navToday => 'اليوم';

  @override
  String get navPlan => 'الخطة';

  @override
  String get navTimeBank => 'بنك الوقت';

  @override
  String get navWallet => 'المحفظة';

  @override
  String get navProfile => 'حسابي';

  @override
  String goodMorning(String name) {
    return 'صباح الخير يا $name 👋';
  }

  @override
  String timeCoinsChip(int count) {
    return '$count نقاط وقت';
  }

  @override
  String get nextUpCardTitle => 'جلسة تركيز فردية';

  @override
  String get nextUpBadge => 'التالي';

  @override
  String todayTimelineTitle(int count) {
    return 'جدول اليوم ($count عناصر)';
  }

  @override
  String get weeklyGoalRate => 'معدل إنجاز الأسبوع';

  @override
  String completedSessionsCount(int done, int total) {
    return 'أنجزت $done من $total جلسات هذا الأسبوع';
  }

  @override
  String get emptyStateTitle => 'لا توجد عناصر حالياً';

  @override
  String get emptyStateSubtitle =>
      'ستظهر العناصر هنا فور إضافتها أو تحديث خطتك';

  @override
  String get errorStateTitle => 'حدث خطأ غير متوقع';

  @override
  String get errorStateSubtitle =>
      'تعذر تحميل البيانات، يرجى التحقق من اتصالك والمحاولة مجدداً';

  @override
  String get retryAction => 'إعادة المحاولة';

  @override
  String get offlineBanner =>
      'أنت في وضع عدم الاتصال • البيانات المعروضة مخزنة محلياً';

  @override
  String get loadingText => 'جاري التحميل...';
}
