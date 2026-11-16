// مطور 1
// التوجيه العام والربط بين جميع شاشات التطبيق مع حراسة المصادقة (Auth Guard)

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_service.dart';
import '../constants/app_constants.dart';
import '../models/app_models.dart';

// شاشات مطور 2
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/email_verification_screen.dart';
import '../../features/onboarding/presentation/academic_setup_screen.dart';
import '../../features/onboarding/presentation/onboarding_profile_screen.dart';
import '../../features/onboarding/presentation/onboarding_courses_screen.dart';
import '../../features/onboarding/presentation/onboarding_rate_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';

// شاشات مطور 3
import '../../features/planner/presentation/today_screen.dart';
import '../../features/planner/presentation/weekly_plan_screen.dart';
import '../../features/planner/presentation/study_block_details_screen.dart';
import '../../features/planner/presentation/schedule_setup_screen.dart';
import '../../features/timebank/presentation/need_help_screen.dart';
import '../../features/timebank/presentation/candidates_screen.dart';
import '../../features/timebank/presentation/booking_screen.dart';
import '../../features/timebank/presentation/my_offers_screen.dart';
import '../../features/timebank/presentation/create_offer_screen.dart';
import '../../features/timebank/presentation/my_sessions_screen.dart';

// شاشات مطور 1
import '../../features/sessions/presentation/session_details_teacher_screen.dart';
import '../../features/sessions/presentation/session_details_learner_screen.dart';
import '../../features/sessions/presentation/rating_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../features/home/main_navigation_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// مستمع لتغييرات حالة المصادقة والملف الشخصي لتحديث مسارات GoRouter تلقائياً
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(Ref ref) {
    ref.listen(authStateProvider, (previous, next) {
      notifyListeners();
    });
    ref.listen(userProfileStreamProvider, (previous, next) {
      notifyListeners();
    });
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/welcome',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);
      final user = authAsync.asData?.value ?? ref.read(authServiceProvider).currentUser;
      final isLoggedIn = user != null;
      final isVerified = user?.emailVerified ?? false;
      final location = state.uri.path;

      final isAuthFlow = location == '/welcome' ||
          location == '/login' ||
          location == '/signup';

      // لا نقوم بالتحويل أثناء قيد التحميل الأولي للمصادقة
      if (authAsync.isLoading) {
        return null;
      }

      // إذا لم يكن مسجلاً، يُسمح له فقط بشاشات الدخول والترحيب
      if (!isLoggedIn) {
        return isAuthFlow ? null : '/welcome';
      }

      // إذا كان مسجلاً لكن لم يؤكد بريده بعد، يُلزم بشاشة التأكيد
      if (!isVerified) {
        return location == '/verify-email' ? null : '/verify-email';
      }

      // المستخدم مسجل ومؤكد البريد:
      // فحص هل المستخدم جديد أم أكمل التهيئة مسبقاً (academicYear, semester, أو isOnboarded: true)
      final profileAsync = ref.read(userProfileStreamProvider);
      if (profileAsync.isLoading) {
        return null;
      }
      final userDoc = profileAsync.value?.data();

      final bool isOnboarded = userDoc != null && (
        (userDoc['isOnboarded'] as bool? ?? false) ||
        (userDoc['onboardingCompleted'] as bool? ?? false) ||
        (userDoc['academicYear'] != null && userDoc['semester'] != null)
      );

      final isAcademicSetupRoute = location == '/academic-setup';
      final isEditParam = state.uri.queryParameters['edit'] == 'true';

      if (!isOnboarded) {
        // مستخدم جديد لم يُكمل التهيئة: يُلزم بدخول شاشة الإعداد الأكاديمي
        return isAcademicSetupRoute ? null : '/academic-setup';
      }

      // مستخدم أكمل التهيئة مسبقاً (Returning user):
      // إذا كان يطلب تعديل بياناته من حسابه عمداً، يُسمح له بفتح الشاشة
      if (isAcademicSetupRoute && isEditParam) {
        return null;
      }

      // وإلا فإنه يتجاوز التهيئة وشاشات الدخول وينتقل مباشرة إلى الشاشة الرئيسية (/today)
      if (isAuthFlow || location == '/verify-email' || isAcademicSetupRoute) {
        return '/today';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/academic-setup',
        builder: (context, state) => AcademicSetupScreen(
          isEditMode: state.uri.queryParameters['edit'] == 'true',
        ),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/onboarding-profile',
        builder: (context, state) => const OnboardingProfileScreen(),
      ),
      GoRoute(
        path: '/onboarding-courses',
        builder: (context, state) => const OnboardingCoursesScreen(),
      ),
      GoRoute(
        path: '/onboarding-rate',
        builder: (context, state) => OnboardingRateScreen(
          courses: state.extra as List<CourseSeed>?,
        ),
      ),
      GoRoute(
        path: '/study-block-details',
        builder: (context, state) => StudyBlockDetailsScreen(
          block: state.extra as StudyBlockModel?,
        ),
      ),
      GoRoute(
        path: '/schedule-setup',
        builder: (context, state) => const ScheduleSetupScreen(),
      ),
      GoRoute(
        path: '/need-help',
        builder: (context, state) => const NeedHelpScreen(),
      ),
      GoRoute(
        path: '/candidates',
        builder: (context, state) => CandidatesScreen(targetCourse: state.extra as CourseSeed?),
      ),
      GoRoute(
        path: '/booking',
        builder: (context, state) => BookingScreen(offer: state.extra as TimeBankOfferModel?),
      ),
      GoRoute(
        path: '/create-offer',
        builder: (context, state) => const CreateOfferScreen(),
      ),
      GoRoute(
        path: '/my-sessions',
        builder: (context, state) => const MySessionsScreen(),
      ),
      GoRoute(
        path: '/session-teacher',
        builder: (context, state) => SessionDetailsTeacherScreen(session: state.extra as TimeBankSessionModel?),
      ),
      GoRoute(
        path: '/session-learner',
        builder: (context, state) => SessionDetailsLearnerScreen(session: state.extra as TimeBankSessionModel?),
      ),
      GoRoute(
        path: '/session-rating',
        builder: (context, state) => RatingScreen(session: state.extra as TimeBankSessionModel?),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plan',
                builder: (context, state) => const WeeklyPlanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/timebank',
                builder: (context, state) => const MyOffersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wallet',
                builder: (context, state) => const WalletScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
