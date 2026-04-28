import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/data/services/otp_verification_args.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/presentation/screens/chat_screen.dart';
import 'package:syno_app/presentation/screens/chats_list_screen.dart';
import 'package:syno_app/presentation/screens/matches_list_screen.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/screens/edit_profile_screen.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/screens/onboarding_screen.dart';
import 'package:syno_app/presentation/screens/discover_screen.dart';
import 'package:syno_app/presentation/screens/profile_screen.dart';
import 'package:syno_app/presentation/screens/register_photos_screen.dart';
import 'package:syno_app/presentation/screens/register_screen2.dart';
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
import 'package:syno_app/presentation/screens/blocked_users_screen.dart' hide Consumer;
import 'package:syno_app/presentation/screens/otp_verification_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await dotenv.load(fileName: "assets/env/.env").catchError((e) {
    if (kDebugMode) print('Could not load .env file, using fallback: $e');
  });

  final String backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:8000';

  runApp(
    ProviderScope(
      overrides: [
        backendUrlProvider.overrideWithValue(backendUrl),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ru'), Locale('ka')],
        path: 'assets/lang',
        fallbackLocale: const Locale('en'),
        saveLocale: true,
        child: const MyApp(),
      ),
    ),
  );
}

/// Router provider that watches auth state to trigger redirects
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: NavigatorRefreshListenable(ref),
    redirect: (context, state) {
      final authState = ref.watch(currentUserProvider);
      final regData = ref.read(registrationProvider);
      final notifier = ref.read(currentUserProvider.notifier);

      // Registration is "started" if we have identifying contact info (email or phone)
      final bool hasStartedRegistration = regData.email.isNotEmpty || regData.phoneNumber.isNotEmpty;

      final user = authState.value;
      final authToken = notifier.authToken;
      final String location = state.uri.path;

      final bool isLoggedIn = user != null;
      final bool hasToken = authToken != null;
      final bool isProfileIncomplete = isLoggedIn && user.birthDate == null;
      
      // Needs registration if: started flow, or authenticated but fetchUser returned null (no profile), or data is missing
      final bool needsRegistration = hasStartedRegistration || (hasToken && !isLoggedIn && !authState.isLoading) || isProfileIncomplete;

      // 1. App Initialization Guard
      if (authState.isLoading) {
        final allowedLoadingRoutes = ['/register-step2', '/register-photos', '/otp-verification', '/theme-selection', '/profile-confirmation'];
        if (allowedLoadingRoutes.contains(location)) return null;
        return location == '/' ? null : '/';
      }

      // 2 & 3. Authentication & Registration Flow Guard
      if (!isLoggedIn) {
        // Routes allowed during the entry/auth/registration process
        final authFlowRoutes = ['/landing', '/login-method', '/otp-verification', '/login', '/register', '/onboarding', '/terms', '/privacy'];
        final registrationRoutes = ['/register-step2', '/register-photos', '/theme-selection', '/profile-confirmation'];

        if (authFlowRoutes.contains(location)) return null;

        if (needsRegistration && registrationRoutes.contains(location)) return null;
        
        if (needsRegistration) return '/register-step2';
        return '/landing';
      }

      // 4. In-App Setup Guard (For logged-in users with incomplete data)
      if (isProfileIncomplete) {
        final setupRoutes = ['/register-step2', '/register-photos', '/theme-selection', '/profile-confirmation'];
        if (setupRoutes.contains(location)) return null;
        return '/register-step2';
      }

      // 5. Fully Authenticated: Prevent going back to Auth screens
      final restrictedRoutes = [
        '/login',
        '/register',
        '/',
        '/onboarding',
        '/otp-verification',
        '/landing',
        '/login-method'
      ];
      if (restrictedRoutes.contains(location)) {
        return '/profile';
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
          final args = state.extra is OtpVerificationArgs ? state.extra as OtpVerificationArgs : null;
          if (args == null) return const LoginMethodScreen();
          return OtpVerificationScreen(args: args);
        },
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const LoginMethodScreen(),
      ),
      GoRoute(
        path: '/register-step2',
        name: 'register-step2',
        builder: (context, state) => const RegisterScreen2(),
      ),
      GoRoute(
        path: '/register-photos',
        name: 'register-photos',
        builder: (context, state) => const RegisterPhotosScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/theme-selection',
        name: 'theme-selection',
        builder: (context, state) => const ThemeSelectionScreen(),
      ),
      GoRoute(
        path: '/profile-confirmation',
        name: 'profile-confirmation',
        builder: (context, state) => const ProfileConfirmationScreen(),
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
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/discover', builder: (context, state) => const DiscoverScreen()),
          GoRoute(path: '/matches', builder: (context, state) => const MatchesListScreen()),
          GoRoute(path: '/chats', builder: (context, state) => const ChatsListScreen()),
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
                builder: (context, state) => const ProfileScreen(isReadOnly: true),
              ),
              GoRoute(
                path: 'settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                      path: 'blocked-users',
                      name: 'blocked-users',
                      builder: (context, state) => const BlockedUsersScreen()),
                  GoRoute(
                      path: 'theme-selection',
                      name: 'settings-theme-selection',
                      builder: (context, state) => const ThemeSelectionScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => ChatScreen(match: state.extra as Match),
      ),
    ],
  );
});

class NavigatorRefreshListenable extends ChangeNotifier {
  NavigatorRefreshListenable(Ref ref) {
    ref.listen(currentUserProvider, (_, __) => notifyListeners());
    ref.listen(registrationProvider, (_, __) => notifyListeners());
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