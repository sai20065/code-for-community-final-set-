import 'package:go_router/go_router.dart';

import '../core/models/booth_model.dart';
import '../core/models/submission_model.dart';
import '../features/citizen/compose/photo_video_screen.dart';
import '../features/citizen/compose/text_compose_screen.dart';
import '../features/citizen/compose/voice_record_screen.dart';
import '../features/citizen/confirmation/submission_confirmation_screen.dart';
import '../features/citizen/home/home_screen.dart';
import '../features/citizen/profile/profile_screen.dart';
import '../features/citizen/reports/my_reports_screen.dart';
import '../features/citizen/reports/report_detail_screen.dart';
import '../features/official/booth/booth_detail_sheet.dart';
import '../features/official/dashboard/dashboard_home_screen.dart';
import '../features/official/map/constituency_map_screen.dart';
import '../features/official/themes/themes_overview_screen.dart';
import '../features/official/tickets/ticket_management_screen.dart';
import '../features/onboarding/language_select_screen.dart';
import '../features/onboarding/signup/aadhaar_upload_screen.dart';
import '../features/onboarding/signup/basic_info_screen.dart';
import '../features/onboarding/signup/location_setup_screen.dart';
import '../features/onboarding/splash_screen.dart';

/// One `GoRouter` for both nav shells (citizen vs official) — role is
/// resolved from Firestore `users/{uid}.role` at login and only changes
/// which branch of routes the app lands on (Section 6).
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/language',
      builder: (context, state) => const LanguageSelectScreen(),
    ),

    // --- Onboarding / signup ---
    GoRoute(
      path: '/signup/aadhaar',
      builder: (context, state) => const AadhaarUploadScreen(),
    ),
    GoRoute(
      path: '/signup/basic-info',
      builder: (context, state) => const BasicInfoScreen(),
    ),
    GoRoute(
      path: '/signup/location',
      builder: (context, state) => const LocationSetupScreen(),
    ),

    // --- Citizen shell ---
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/compose/voice',
      builder: (context, state) => const VoiceRecordScreen(),
    ),
    GoRoute(
      path: '/compose/text',
      builder: (context, state) => const TextComposeScreen(),
    ),
    GoRoute(
      path: '/compose/photo',
      builder: (context, state) => const PhotoVideoScreen(),
    ),
    GoRoute(
      path: '/confirmation',
      builder: (context, state) => SubmissionConfirmationScreen(
        submission: state.extra as SubmissionModel,
      ),
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const MyReportsScreen(),
    ),
    GoRoute(
      path: '/reports/:id',
      builder: (context, state) => ReportDetailScreen(
        submissionId: state.pathParameters['id']!,
        submission: state.extra as SubmissionModel?,
      ),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),

    // --- Official shell ---
    GoRoute(
      path: '/official/dashboard',
      builder: (context, state) => const DashboardHomeScreen(),
    ),
    GoRoute(
      path: '/official/map',
      builder: (context, state) => const ConstituencyMapScreen(),
    ),
    GoRoute(
      path: '/official/booth/:id',
      builder: (context, state) => BoothDetailSheet(
        booth: state.extra as BoothModel,
      ),
    ),
    GoRoute(
      path: '/official/themes',
      builder: (context, state) => const ThemesOverviewScreen(),
    ),
    GoRoute(
      path: '/official/tickets',
      builder: (context, state) => const TicketManagementScreen(),
    ),
  ],
);
