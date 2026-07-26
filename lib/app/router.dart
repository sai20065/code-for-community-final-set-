import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/booth_model.dart';
import '../core/models/submission_model.dart';
import '../core/models/user_model.dart';
import '../features/citizen/compose/category_picker_screen.dart';
import '../features/citizen/compose/photo_video_screen.dart';
import '../features/citizen/compose/text_compose_screen.dart';
import '../features/citizen/compose/voice_record_screen.dart';
import '../features/citizen/confirmation/submission_confirmation_screen.dart';
import '../features/citizen/home/home_screen.dart';
import '../features/citizen/profile/profile_screen.dart';
import '../features/citizen/reports/my_reports_screen.dart';
import '../features/citizen/reports/report_detail_screen.dart';
import '../features/official/report/generate_report_screen.dart';
import '../features/official/tickets/ticket_management_screen.dart';
import '../features/official/transcript/agent_transcript_screen.dart';
import '../features/onboarding/gov_login_screen.dart';
import '../features/onboarding/language_select_screen.dart';
import '../features/onboarding/mp_credentials_request_screen.dart';
import '../features/onboarding/signin_screen.dart';
import '../features/onboarding/signup/basic_info_screen.dart';
import '../features/onboarding/signup/location_setup_screen.dart';
import '../features/onboarding/signup/onboarding_done_screen.dart';
import '../features/onboarding/signup_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/official/dashboard/gov_dashboard_screen.dart';
import '../features/public/area_picker/area_picker_screen.dart';
import '../features/public/booth/booth_detail_sheet.dart';
import '../features/public/constituency_picker/constituency_picker_screen.dart';
import '../features/public/dashboard/dashboard_home_screen.dart';
import '../features/public/map/constituency_map_screen.dart';
import '../features/public/solution/solution_card_screen.dart';
import '../features/public/themes/themes_overview_screen.dart';
import '../features/public/works/compare_proposals_screen.dart';
import '../features/public/works/ranked_works_screen.dart';
import 'providers/current_user_profile_provider.dart';
import 'providers/public_data_providers.dart';

/// Routes that were `/official/*` before the dashboard was made public, kept
/// as redirects so existing deep links, bookmarks and any shared URL keep
/// working rather than 404-ing.
const _legacyOfficialRedirects = <String, String>{
  '/official/dashboard': '/public/dashboard',
  '/official/map': '/public/map',
  '/official/themes': '/public/themes',
  '/official/works': '/public/works',
  '/official/compare': '/public/compare',
};

/// Routes that genuinely still require the official role. Everything else
/// under `/official/*` moved to `/public/*` when the dashboard was opened up.
const _officialOnlyPrefixes = <String>[
  '/official/tickets',
  '/official/report',
  '/official/transcript',
  '/gov/dashboard',
];

/// The app's router.
///
/// A provider rather than a bare global because role gating needs to read
/// auth state: `/official/tickets` and `/official/report` must bounce a
/// non-official to the public dashboard, and that decision can only be made
/// once `currentUserProfileProvider` has resolved.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final path = state.uri.path;

      // A shared link can carry the constituency it was shared from
      // (`/public/dashboard?c=blr-north`), so a recipient with no account
      // and no stored preference lands on the right area immediately.
      final linkedConstituency = state.uri.queryParameters['c'];
      if (linkedConstituency != null && linkedConstituency.isNotEmpty) {
        ref.read(publicConstituencyProvider.notifier).adoptFromLink(
              linkedConstituency,
            );
      }

      final legacy = _legacyOfficialRedirects[path];
      if (legacy != null) return legacy;

      if (_officialOnlyPrefixes.any(path.startsWith)) {
        final profileAsync = ref.read(currentUserProfileProvider);
        // While the profile is still loading, don't redirect — bouncing on
        // an unresolved value would kick a genuine official out of their own
        // screen on every cold start.
        if (profileAsync.isLoading) return null;
        final profile = profileAsync.valueOrNull;
        if (profile?.role != UserRole.official) return '/public/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/language',
        builder: (context, state) =>
            LanguageSelectScreen(fromSettings: state.extra == true),
      ),

      // --- Onboarding / signup ---
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/signin',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/gov/login',
        builder: (context, state) => const GovLoginScreen(),
      ),
      GoRoute(
        path: '/gov/dashboard',
        builder: (context, state) => const GovDashboardScreen(),
      ),
      GoRoute(
        path: '/mp/first-time-setup',
        builder: (context, state) => const MpCredentialsRequestScreen(isFirstTime: true),
      ),
      GoRoute(
        path: '/mp/forgot-credentials',
        builder: (context, state) => const MpCredentialsRequestScreen(isFirstTime: false),
      ),
      GoRoute(
        path: '/signup/basic-info',
        builder: (context, state) => const BasicInfoScreen(),
      ),
      GoRoute(
        path: '/signup/location',
        builder: (context, state) => const LocationSetupScreen(),
      ),
      GoRoute(
        path: '/signup/done',
        builder: (context, state) => const OnboardingDoneScreen(),
      ),

      // --- Citizen shell ---
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/compose',
        builder: (context, state) => const CategoryPickerScreen(),
      ),
      GoRoute(
        path: '/compose/voice',
        builder: (context, state) => VoiceRecordScreen(
          initialCategory: state.extra as SubmissionCategory?,
        ),
      ),
      GoRoute(
        path: '/compose/text',
        builder: (context, state) => TextComposeScreen(
          initialCategory: state.extra as SubmissionCategory?,
        ),
      ),
      GoRoute(
        path: '/compose/photo',
        builder: (context, state) => PhotoVideoScreen(
          initialCategory: state.extra as SubmissionCategory?,
        ),
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

      // --- Public dashboard: no sign-in required, anywhere below here ---
      GoRoute(
        path: '/public/constituency',
        builder: (context, state) => const ConstituencyPickerScreen(),
      ),
      // District → Taluk (or → BBMP ward inside Bengaluru) picker. The
      // primary way in: people know their district and taluk, almost nobody
      // knows their Lok Sabha constituency by name.
      GoRoute(
        path: '/public/area',
        builder: (context, state) => const AreaPickerScreen(),
      ),
      GoRoute(
        path: '/public/dashboard',
        builder: (context, state) => const DashboardHomeScreen(),
      ),
      GoRoute(
        path: '/public/map',
        builder: (context, state) => const ConstituencyMapScreen(),
      ),
      GoRoute(
        path: '/public/booth/:id',
        builder: (context, state) => BoothDetailSheet(
          booth: state.extra as BoothModel,
        ),
      ),
      GoRoute(
        path: '/public/themes',
        builder: (context, state) => const ThemesOverviewScreen(),
      ),
      GoRoute(
        path: '/public/works',
        builder: (context, state) => const RankedWorksScreen(),
      ),
      GoRoute(
        path: '/public/compare',
        builder: (context, state) => const CompareProposalsScreen(),
      ),
      GoRoute(
        path: '/public/cluster/:clusterId',
        builder: (context, state) => SolutionCardScreen(
          clusterId: state.pathParameters['clusterId']!,
        ),
      ),

      // --- Official-only: gated by the top-level redirect above ---
      GoRoute(
        path: '/official/tickets',
        builder: (context, state) => const TicketManagementScreen(),
      ),
      GoRoute(
        path: '/official/report',
        builder: (context, state) => const GenerateReportScreen(),
      ),
      GoRoute(
        path: '/official/transcript/:clusterId',
        builder: (context, state) => AgentTranscriptScreen(
          clusterId: state.pathParameters['clusterId']!,
        ),
      ),

      // Legacy `/official/*` paths handled by the top-level redirect need a
      // route to match against, or GoRouter reports them as not found before
      // the redirect ever runs.
      for (final legacy in _legacyOfficialRedirects.keys)
        GoRoute(path: legacy, redirect: (_, __) => _legacyOfficialRedirects[legacy]),
      GoRoute(
        path: '/official/booth/:id',
        redirect: (context, state) =>
            '/public/booth/${state.pathParameters['id']}',
      ),
    ],
  );
});
