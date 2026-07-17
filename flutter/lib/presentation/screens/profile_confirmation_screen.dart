import 'package:cross_file/src/types/interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/data/services/user_service.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'package:syno_app/presentation/providers/theme_update_provider.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/providers/loading_provider.dart';
import 'package:syno_app/presentation/providers/user_state_notifier.dart';
import 'package:syno_app/presentation/widgets/app_dialogs.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:syno_app/presentation/utils/error_localization.dart';

class ProfileConfirmationScreen extends ConsumerWidget {
  const ProfileConfirmationScreen({super.key});

  Future<void> _onConfirm(BuildContext context, WidgetRef ref) async {
    final LoadingStateNotifier loadingNotifier = ref.read(loadingStateProvider.notifier);
    final RegistrationState registrationState = ref.read(registrationProvider);
    final UserService userService = ref.read(userServiceProvider);
    final UserStateNotifier currentUserNotifier = ref.read(currentUserProvider.notifier);

    loadingNotifier.show();
    try {
      final photoPaths = registrationState.photos.map((e) => e.path).toList();

      final Map<String, dynamic> themeData = {};
      if (registrationState.profileData.themeId != null) {
        themeData['theme_id'] = registrationState.profileData.themeId;
        themeData['background_color'] = registrationState.profileData.backgroundColor;
        themeData['accent_color'] = registrationState.profileData.accentColor;
        themeData['layout'] = registrationState.profileData.layout ?? 'default';
      }

      await userService.createProfileWithPhotos(
        registrationState.profileData.toJson(),
        photoPaths,
        firstIsPrimary: true,
      );

      if (themeData.isNotEmpty) {
        final AppThemeData newTheme = AppThemeData.fromJson(themeData);
        await ref.read(themeUpdateProvider.notifier).updateTheme(newTheme);
      } else {
        await currentUserNotifier.refreshUser();
      }

      if (context.mounted) context.goNamed('discover');
    } catch (e) {
      if (context.mounted) AppDialogs.showErrorDialog(context, 'register.error_title'.tr(), resolveLocalizedMessage(e.toString(), context: context));
    } finally {
      loadingNotifier.hide();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeData theme = ref.watch(themeProvider);

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
              children: <Widget>[
                const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                const SizedBox(height: 24),
                Text(
                  'register.profile_ready_message'.tr(),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.primaryTextColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text('register.welcome_message'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.secondaryTextColor)),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () => _onConfirm(context, ref),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: theme.accentColor,
                    foregroundColor: theme.accentColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                  ),
                  child: Text('register.complete_registration'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}