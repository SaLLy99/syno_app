
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/presentation/widgets/cosmic_button.dart';
import 'package:syno_app/theme.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingXl,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Removed <dynamic>
            children: <Widget>[
              Image.asset('assets/icons/package:syno_app_icon.jpg', width: 300, height: 300),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'onboarding.welcome'.tr(),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'onboarding.tagline'.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'onboarding.description'.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: CosmicButton(
                  text: 'onboarding.get_started'.tr(),
                  icon: Icons.rocket_launch,
                  onPressed: () {
                    context.go('/register');
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'onboarding.demo_notice'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
