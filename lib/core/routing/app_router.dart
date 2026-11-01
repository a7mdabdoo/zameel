// مطور 1
// التوجيه العام والربط بين جميع شاشات التطبيق

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// شاشات مطور 2
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
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

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/welcome',
  routes: [
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
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
      builder: (context, state) => const OnboardingRateScreen(),
    ),
    GoRoute(
      path: '/study-block-details',
      builder: (context, state) => const StudyBlockDetailsScreen(),
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
      builder: (context, state) => const CandidatesScreen(),
    ),
    GoRoute(
      path: '/booking',
      builder: (context, state) => const BookingScreen(),
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
      builder: (context, state) => const SessionDetailsTeacherScreen(),
    ),
    GoRoute(
      path: '/session-learner',
      builder: (context, state) => const SessionDetailsLearnerScreen(),
    ),
    GoRoute(
      path: '/session-rating',
      builder: (context, state) => const RatingScreen(),
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
