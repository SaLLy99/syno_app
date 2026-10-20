import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/data/services/otp_verification_args.dart';
import 'package:syno_app/data/services/websocket_service.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/presentation/screens/chat_screen.dart';
import 'package:syno_app/presentation/screens/chats_list_screen.dart';
import 'package:syno_app/presentation/screens/matches_list_screen.dart';
import 'package:syno_app/presentation/screens/likes_list_screen.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/screens/edit_profile_screen.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/screens/onboarding_screen.dart';
import 'package:syno_app/presentation/screens/discover_screen.dart';
import 'package:syno_app/presentation/screens/recommendations_screen.dart';
import 'package:syno_app/presentation/screens/compatibility_report_screen.dart';
import 'package:syno_app/presentation/screens/analytics_screen.dart';
import 'package:syno_app/presentation/providers/websocket_provider.dart';
import 'package:syno_app/presentation/screens/profile_screen.dart';
import 'package:syno_app/presentation/screens/register_photos_screen.dart';
import 'package:syno_app/presentation/screens/register_mode_screen.dart';
import 'package:syno_app/presentation/screens/register_intentions_screen.dart';
import 'package:syno_app/presentation/screens/register_values_screen.dart';
import 'package:syno_app/presentation/screens/register_hobbies_screen.dart';
import 'package:syno_app/presentation/screens/register_career_screen.dart';
import 'package:syno_app/presentation/screens/register_bio_screen.dart';
import 'package:syno_app/presentation/screens/register_name_screen.dart';
import 'package:syno_app/presentation/screens/register_identity_screen.dart';
import 'package:syno_app/presentation/screens/register_birth_screen.dart';
import 'package:syno_app/presentation/screens/theme_selection_screen.dart';
import 'package:syno_app/presentation/screens/settings_screen.dart';
import 'package:syno_app/presentation/screens/profile_confirmation_screen.dart';
import 'package:syno_app/presentation/screens/landing_screen.dart';
import 'package:syno_app/presentation/screens/privacy_screen.dart';
import 'package:syno_app/presentation/screens/terms_screen.dart';
import 'package:syno_app/presentation/screens/splash_screen.dart';
import 'package:syno_app/presentation/providers/loading_provider.dart';
import 'package:syno_app/presentation/screens/main_shell.dart';
import 'package:syno_app/presentation/screens/login_screen.dart';
import 'package:syno_app/presentation/screens/login_method_screen.dart';
import 'package:syno_app/presentation/screens/theme.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/screens/blocked_users_screen.dart';
import 'package:syno_app/presentation/screens/otp_verification_screen.dart';
import 'package:syno_app/presentation/screens/synastry_detail_screen.dart';
import 'package:syno_app/presentation/screens/matches_details_screen.dart';
import 'package:syno_app/presentation/screens/reactivation_screen.dart';

Locale _resolveStartLocale() {
  final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
  const supportedLocales = [Locale('en'), Locale('ru'), Locale('ka')];

  for (final locale in supportedLocales) {
    if (locale.languageCode == deviceLocale.languageCode) {
      return locale;
    }
  }

  return const Locale('en');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await dotenv.load(fileName: "assets/env/.env").catchError((e) {
    if (kDebugMode) print('Could not load .env file, using fallback: $e');
  });

  final String backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:8000';

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('backend_url', backendUrl);

  runApp(
    ProviderScope(
      overrides: [
        backendUrlProvider.overrideWithValue(backendUrl),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ru'), Locale('ka')],
        path: 'assets/lang',
        fallbackLocale: const Locale('en'),
        saveLocale: false,
        useOnlyLangCode: true,
        startLocale: _resolveStartLocale(),
        child: const MyApp(),
      ),
    ),
  );
}

/// Router provider that watches auth state to trigger redirects
Page<void> _slideTransitionPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offsetAnimation =
          Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeInOut))
              .animate(animation);
      return SlideTransition(position: offsetAnimation, child: child);
    },
  );
}

/// Route collections for efficient lookup in redirects
const _authFlowRoutes = {
  '/landing',
  '/login-method',
  '/otp-verification',
  '/login',
  '/register',
  '/onboarding',
  '/terms',
  '/privacy',
};

const _registrationRoutes = {
  '/register-name',
  '/register-photos',
  '/register-mode',
  '/register-identity',
  '/register-birth',
  '/register-intentions',
  '/register-values',
  '/register-hobbies',
  '/register-career',
  '/register-bio',
  '/theme-selection',
  '/profile-confirmation',
};

final routerProvider =Provider<GoRouter>((ref) {
  // Use WATCH here so the router reacts to user state changes
  final authState = ref.watch(currentUserProvider);
  
  return GoRouter(
    initialLocation: '/',
    refreshListenable: NavigatorRefreshListenable(ref),
    redirect: (context, state) {
      final regData = ref.read(registrationProvider);

      // Registration is "started" if we have identifying contact info (email or phone)
      final bool hasStartedRegistration = regData.email.isNotEmpty || regData.phoneNumber.isNotEmpty;

      final notifier = ref.read(currentUserProvider.notifier);
      final user = authState.value;
      final String location = state.uri.path;
      final bool hasToken = notifier.authToken?.trim().isNotEmpty ?? false;

      final bool isLoggedIn = user != null;
      final bool isProfileIncomplete = isLoggedIn && (user.name == null || user.birthDate == null);
      // If user just reactivated, they have a token but no profile - skip OTP, go to registration
      final bool justReactivated = notifier.justReactivated;
      final bool needsRegistration = hasStartedRegistration || (hasToken && !isLoggedIn && !justReactivated) || isProfileIncomplete;

      // 1. App Initialization Guard
      if (authState.isLoading) {
        final allowedLoadingRoutes = ['/register-photos', '/register-mode', '/otp-verification', '/theme-selection', '/profile-confirmation', '/register-name', '/register-identity', '/register-birth', '/register-intentions', '/register-values', '/register-hobbies', '/register-career', '/register-bio', '/reactivation'];
        if (allowedLoadingRoutes.contains(location)) return null;
        return location == '/' ? null : '/';
      }

      // 2. Logged-in users with a completed profile should not stay on auth/registration entry routes.
      if (isLoggedIn && !isProfileIncomplete) {
        // Clear the reactivated flag and stale registration data once the profile is confirmed complete
        if (justReactivated) {
          notifier.clearJustReactivated();
          ref.read(registrationProvider.notifier).reset();
        }
        final authEntryRoutes = {'/', '/landing', '/login-method', '/otp-verification', '/login', '/register'};
        final registrationRoutes = {'/register-name', '/register-photos', '/register-mode', '/register-identity', '/register-birth', '/register-intentions', '/register-values', '/register-hobbies', '/register-career', '/register-bio', '/theme-selection', '/profile-confirmation'};
        if (authEntryRoutes.contains(location) || registrationRoutes.contains(location)) {
          return '/discover';
        }
      }

      // 3. Authentication & Registration Flow Guard
      if (!isLoggedIn) {
        // Routes allowed during the entry/auth/registration process
        final authFlowRoutes = {'/landing', '/login-method', '/otp-verification', '/login', '/register', '/onboarding', '/terms', '/privacy', '/reactivation'};
        final registrationRoutes = {'/register-name', '/register-photos', '/register-mode', '/register-identity', '/register-birth', '/register-intentions', '/register-values', '/register-hobbies', '/register-career', '/register-bio', '/theme-selection', '/profile-confirmation'};

        if (authFlowRoutes.contains(location)) return null;
        if (needsRegistration && registrationRoutes.contains(location)) return null;
        // If user just reactivated, allow registration routes directly (skip OTP)
        if (justReactivated && registrationRoutes.contains(location)) return null;
        if (justReactivated) {
          // Reactivation succeeded but user fetch failed — clear flag and go to landing
          notifier.clearJustReactivated();
          ref.read(registrationProvider.notifier).reset();
          return '/landing';
        }
        if (needsRegistration) return '/register-name';
        return '/landing';
      }

      // 4. In-App Setup Guard (For logged-in users with incomplete data)
      if (isProfileIncomplete) {
        final setupRoutes = {'/register-name', '/register-photos', '/register-mode', '/register-identity', '/register-birth', '/register-intentions', '/register-values', '/register-hobbies', '/register-career', '/register-bio', '/theme-selection', '/profile-confirmation'};
        if (setupRoutes.contains(location)) return null;
        return '/register-name';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      GoRoute(
        path: '/landing',
        name: 'landing',
        builder: (context, state) => const LandingScreen(),
      ),

      GoRoute(
        path: '/login-method',
        name: 'login-method',
        builder: (context, state) => const LoginMethodScreen(),
      ),

      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      GoRoute(
        path: '/otp-verification',
        name: 'otp-verification',
        builder: (context, state) {
          final args = state.extra is OtpVerificationArgs
              ? state.extra as OtpVerificationArgs
              : null;

          if (args == null) {
            return const LoginMethodScreen();
          }

          return OtpVerificationScreen(args: args);
        },
      ),

      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const LoginMethodScreen(),
      ),

      GoRoute(
        path: '/register-photos',
        name: 'register-photos',
        pageBuilder: (context, state) => _slideTransitionPage(
          state,
          const RegisterPhotosScreen(),
        ),
      ),

      GoRoute(
        path: '/register-mode',
        name: 'register-mode',
        pageBuilder: (context, state) => _slideTransitionPage(
          state,
          const RegisterModeScreen(),
        ),
      ),

      GoRoute(
        path: '/register-name',
        name: 'register-name',
        pageBuilder: (context, state) => _slideTransitionPage(
          state,
          const RegisterNameScreen(),
        ),
      ),

      GoRoute(
        path: '/register-identity',
        name: 'register-identity',
        pageBuilder: (context, state) => _slideTransitionPage(
          state,
          const RegisterIdentityScreen(),
        ),
      ),

      GoRoute(
        path: '/register-birth',
        name: 'register-birth',
        pageBuilder: (context, state) => _slideTransitionPage(
          state,
          const RegisterBirthScreen(),
        ),
      ),

      GoRoute(
        path: '/register-intentions',
        name: 'register-intentions',
        pageBuilder: (context, state) => _slideTransitionPage(
          state,
          const RegisterIntentionsScreen(),
        ),
      ),

      GoRoute(
        path: '/register-values',
        name: 'register-values',
        pageBuilder: (context, state) => _slideTransitionPage(
          state,
          const RegisterValuesScreen(),
        ),
      ),

      GoRoute(
        path: '/register-hobbies',
        name: 'register-hobbies',
        pageBuilder: (context, state) => _slideTransitionPage(
          state,
          const RegisterHobbiesScreen(),
        ),
      ),

      GoRoute(
        path: '/register-career',
        name: 'register-career',
        pageBuilder: (context, state) => _slideTransitionPage(
          state,
          const RegisterCareerScreen(),
        ),
      ),

      GoRoute(
        path: '/register-bio',
        name: 'register-bio',
        pageBuilder: (context, state) => _slideTransitionPage(
          state,
          const RegisterBioScreen(),
        ),
      ),

      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) => _slideTransitionPage(
          state,
          const OnboardingScreen(),
        ),
      ),

      GoRoute(
        path: '/theme-selection',
        name: 'theme-selection',
        pageBuilder: (context, state) => _slideTransitionPage(
          state,
          const ThemeSelectionScreen(),
        ),
      ),

      GoRoute(
        path: '/profile-confirmation',
        name: 'profile-confirmation',
        pageBuilder: (context, state) => _slideTransitionPage(
          state,
          const ProfileConfirmationScreen(),
        ),
      ),

      GoRoute(
        path: '/terms',
        name: 'terms',
        builder: (context, state) => const TermsScreen(),
      ),

      GoRoute(
        path: '/privacy',
        name: 'privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),

      ShellRoute(
        builder: (context, state, child) {
          return MainShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/discover',
            builder: (context, state) => const DiscoverScreen(),
          ),

          GoRoute(
            path: '/recommendations',
            builder: (context, state) => const RecommendationsScreen(),
          ),

          GoRoute(
            path: '/likes',
            builder: (context, state) => const LikesListScreen(),
          ),

          GoRoute(
            path: '/matches',
            builder: (context, state) => const MatchesListScreen(),
          ),

          GoRoute(
            path: '/chats',
            builder: (context, state) => const ChatsListScreen(),
          ),

          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'edit',
                name: 'edit-profile',
                builder: (context, state) => const EditProfileScreen(),
              ),

              GoRoute(
                path: 'preview',
                name: 'profile-preview',
                builder: (context, state) {
                  return const ProfileScreen(isReadOnly: true);
                },
              ),

              GoRoute(
                path: 'settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'blocked-users',
                    name: 'blocked-users',
                    builder: (context, state) {
                      return const BlockedUsersScreen();
                    },
                  ),

                  GoRoute(
                    path: 'theme-selection',
                    name: 'settings-theme-selection',
                    builder: (context, state) {
                      return const ThemeSelectionScreen();
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: '/chat',
        builder: (context, state) {
          return ChatScreen(match: state.extra as Match);
        },
      ),

      GoRoute(
        path: '/match-details',
        name: 'match-details',
        builder: (context, state) {
          final match = state.extra as Match;
          return MatchDetailsScreen(match: match);
        },
      ),

      GoRoute(
        path: '/synastry-report',
        name: 'synastry-report',
        builder: (context, state) {
          final match = state.extra as Match;
          return SynastryDetailScreen(match: match);
        },
      ),

      GoRoute(
        path: '/synastry-detail',
        name: 'synastry-detail',
        builder: (context, state) {
          final match = state.extra as Match;
          return SynastryDetailScreen(match: match);
        },
      ),

      GoRoute(
        path: '/compatibility-report',
        name: 'compatibility-report',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>;
          final int matchId = args['matchId'] as int;
          final String matchedUserName = args['matchedUserName'] as String;
          return CompatibilityReportScreen(
            matchId: matchId,
            matchedUserName: matchedUserName,
          );
        },
      ),

      GoRoute(
        path: '/analytics',
        name: 'analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),

      GoRoute(
        path: '/reactivation',
        name: 'reactivation',
        builder: (context, state) => const ReactivationScreen(),
      ),
    ],
  );
});

class NavigatorRefreshListenable extends ChangeNotifier {
  NavigatorRefreshListenable(Ref ref) {
    ref.listen(currentUserProvider, (_, __) => notifyListeners());
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appTheme = ref.watch(themeProvider);

    final isDark = appTheme.primaryTextColor.computeLuminance() > 0.5;
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final baseTheme = isDark ? purpleTheme : lightTheme;

    final effectiveTheme = baseTheme.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      primaryColor: appTheme.accentColor,
      textTheme: baseTheme.textTheme.apply(
        bodyColor: appTheme.primaryTextColor,
        displayColor: appTheme.primaryTextColor,
      ),
      iconTheme: baseTheme.iconTheme.copyWith(color: appTheme.primaryTextColor),
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: appTheme.primaryTextColor),
        titleTextStyle: TextStyle(color: appTheme.primaryTextColor, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: appTheme.accentColor,
        brightness: brightness,
        primary: appTheme.accentColor,
        onSurface: appTheme.primaryTextColor,
      ),
    );

    return MaterialApp.router(
      title: 'SYNO',
      debugShowCheckedModeBanner: false,
      theme: effectiveTheme,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routerConfig: router,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          gradient: appTheme.gradient,
          color: appTheme.gradient == null ? Colors.black : null,
        ),
        child: Stack(
          children: [
            if (child != null) child,
            Consumer(builder: (context, ref, _) {
              final WebSocketStatus wsStatus = ref.watch(webSocketProvider);
              if (wsStatus == WebSocketStatus.connected) {
                return const SizedBox.shrink();
              }
              return const SizedBox.shrink();
            }),
            Consumer(builder: (context, ref, _) {
              if (!ref.watch(loadingStateProvider)) return const SizedBox.shrink();
              return Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              );
            }),
          ],
        ),
      ),
    );
  }
}