import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';

class ProfileConfirmationScreen extends ConsumerWidget {
  const ProfileConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Profile Ready', style: TextStyle(color: theme.primaryTextColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.primaryTextColor),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                const SizedBox(height: 24),
                Text(
                  'Your profile looks amazing!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.primaryTextColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text('You are all set to start exploring.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.secondaryTextColor)),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    // Finalize flow and go to the main app (Discover)
                    context.goNamed('discover');
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: theme.accentColor,
                    foregroundColor: theme.accentColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                  ),
                  child: const Text('Confirm & Start'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}