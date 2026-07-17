import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:syno_app/presentation/screens/theme.dart';

class OnboardingScaffold extends StatelessWidget {
  final String title;
  final double progress;
  final Widget child;
  final VoidCallback? onContinue;
  final bool canContinue;
  final String? continueLabel;

  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.progress,
    required this.child,
    this.onContinue,
    this.canContinue = true,
    this.continueLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          title,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration:
            const BoxDecoration(gradient: CosmicColors.deepSpaceGradient),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: progress),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    builder: (BuildContext context, double animatedProgress, Widget? child) {
                      return LinearProgressIndicator(
                        value: animatedProgress,
                        backgroundColor: Colors.white10,
                        color: CosmicColors.cosmicPink,
                        minHeight: 6,
                      );
                    },
                  ),
                ),
              ),
              Expanded(child: child),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canContinue ? onContinue : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: canContinue
                          ? CosmicColors.cosmicPink
                          : Colors.grey.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      continueLabel ?? 'register.continue'.tr(),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
