import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/presentation/screens/chat_screen.dart';
import 'package:syno_app/presentation/screens/chats_list_screen.dart';
import 'package:syno_app/presentation/screens/matches_details_screen.dart';
import 'package:syno_app/presentation/screens/matches_list_screen.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/screens/edit_profile_screen.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/screens/onboarding_screen.dart';
import 'package:syno_app/presentation/screens/discover_screen.dart';
import 'package:syno_app/presentation/screens/profile_screen.dart';
import 'package:syno_app/presentation/screens/register_photos_screen.dart';
import 'package:syno_app/presentation/screens/register_screen.dart';
import 'package:syno_app/presentation/screens/register_screen2.dart';
import 'package:syno_app/presentation/screens/theme_selection_screen.dart';
import 'package:syno_app/presentation/screens/theme_customization_screen.dart';
import 'package:syno_app/presentation/screens/settings_screen.dart';
import 'package:syno_app/presentation/screens/profile_confirmation_screen.dart';
import 'package:syno_app/presentation/screens/landing_screen.dart';
import 'package:syno_app/presentation/screens/legal_screen.dart';
import 'package:syno_app/presentation/screens/privacy_screen.dart';
import 'package:syno_app/presentation/screens/terms_screen.dart';
import 'package:syno_app/presentation/screens/splash_screen.dart';
import 'package:syno_app/presentation/providers/loading_provider.dart';
import 'package:syno_app/presentation/screens/main_shell.dart';
import 'package:syno_app/presentation/screens/synastry_report_screen.dart';
import 'package:syno_app/presentation/screens/login_screen.dart';
import 'package:syno_app/presentation/screens/theme.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/screens/blocked_users_screen.dart' hide Consumer;


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

/// Helper to convert hex strings to Flutter Color objects
Color? _hexToColor(String? hexString) {
  if (hexString == null) return null;
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  try {
    return Color(int.parse(buffer.toString(), radix: 16));
  } catch (e) {
    return null;
  }
}

/// Router provider that watches auth state to trigger redirects
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    // This allows GoRouter to rebuild/redirect whenever the auth state changes
    refreshListenable: NavigatorRefreshListenable(ref), 
    redirect: (context, state) {
      // By reading the state within the redirect, we ensure we always have the latest values.
      // The NavigatorRefreshListenable is responsible for triggering this redirect when the state changes.
      final authState = ref.read(currentUserProvider);
      final isRegistrationInProgress = ref.read(registrationProvider).step1Data.isNotEmpty;

      final user = authState.value;
      final bool isLoading = authState.isLoading;
      
      // Use .path to get the clean route string (e.g., '/register-step2')
      final String location = state.uri.path; 

      // 1. While app is initializing
      if (isLoading) {
        // If we are in the middle of the registration flow, don't redirect to splash.
        // The registration screen will handle its own loading indicator, preventing a race condition.
        if (isRegistrationInProgress && (location == '/register-step2' || location == '/register-photos')) {
          return null;
        }
        return location == '/' ? null : '/';
      }

      final bool isLoggedIn = user != null;
      
      // IMPORTANT: Ensure your User entity birthDate is actually null before Step 2
      final bool isProfileComplete = isLoggedIn && user.birthDate != null;

      // 2. Auth Guard: Not Logged In
      if (!isLoggedIn) {
        final publicRoutes = [
          '/login', 
          '/register', 
          '/register-step2',
          '/register-photos',
          '/onboarding',
          '/landing',
          '/terms',
          '/privacy'
        ];

        // Guard: If on registration steps 2 or 3 but missing step 1 data, restart registration.
        if ((location == '/register-step2' || location == '/register-photos') && !isRegistrationInProgress) {
          return '/register';
        }

        if (publicRoutes.contains(location)) return null;
        return '/landing';
      }

      // 3. Setup Guard: Logged In but Profile Incomplete
      // This is the part that was likely failing
      if (!isProfileComplete) {
        final setupRoutes = [
          '/register-step2', 
          '/register-photos', 
          '/theme-selection', 
          '/profile-confirmation'
        ];
        
        // If they are already on one of these setup screens, let them stay
        if (setupRoutes.contains(location)) return null;
        
        // Otherwise, force them to Step 2
        return '/register-step2';
      }

      // 4. Fully Authenticated: Prevent going back to Login/Register/Splash
      final restrictedRoutes = ['/login', '/register', '/', '/onboarding'];
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
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
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
      GoRoute(
        path: '/register-step2',
        name: 'register-step2',
        builder: (context, state) {
          return const RegisterScreen2();
        },
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/register-photos',
        name: 'register-photos',
        builder: (context, state) {
          return const RegisterPhotosScreen();
        },
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
      // App Shell (Navigation Bar)
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
      // Standalone screens (No Bottom Bar)
      GoRoute(
        path: '/chat',
        builder: (context, state) => ChatScreen(match: state.extra as Match),
      ),
    ],
  );
});

/// Custom Listenable to bridge Riverpod to GoRouter
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
    // Watch the theme provider for global theme changes
    final appTheme = ref.watch(themeProvider);

    // Determine brightness based on text color (light text implies dark background)
    final isDark = appTheme.primaryTextColor.computeLuminance() > 0.5;
    final brightness = isDark ? Brightness.dark : Brightness.light;

    // Use existing base themes if available, otherwise fallback
    final baseTheme = isDark ? purpleTheme : lightTheme;

    final effectiveTheme = baseTheme.copyWith(
      // Apply colors from AppThemeData
      scaffoldBackgroundColor: Colors.transparent,
      primaryColor: appTheme.accentColor,
      
      // Text Theme
      textTheme: baseTheme.textTheme.apply(
        bodyColor: appTheme.primaryTextColor,
        displayColor: appTheme.primaryTextColor,
      ),
      
      // Icon Theme
      iconTheme: baseTheme.iconTheme.copyWith(color: appTheme.primaryTextColor),
      
      // AppBar Theme
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: appTheme.primaryTextColor),
        titleTextStyle: TextStyle(color: appTheme.primaryTextColor, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      
      // Color Scheme
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
            // Global Loading Overlay
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