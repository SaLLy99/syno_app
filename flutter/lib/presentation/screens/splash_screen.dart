import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'package:syno_app/theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: theme.id == 'deep_space' ? CosmicColors.cosmicGradient : LinearGradient(colors: [theme.accentColor.withOpacity(0.7), theme.accentColor]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.accentColor.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/icons/dreamflow_icon.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Text(
              //   'SYNO',
              //   style: Theme.of(context).textTheme.displayMedium?.copyWith(
              //     color: Colors.white,
              //     fontWeight: FontWeight.bold,
              //     letterSpacing: 4,
              //   ),
              // ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your Cosmic Match',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: theme.primaryTextColor.withOpacity(0.9),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
