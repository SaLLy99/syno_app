import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/widgets/onboarding_scaffold.dart';

class RegisterBioScreen extends ConsumerStatefulWidget {
  const RegisterBioScreen({super.key});

  @override
  ConsumerState<RegisterBioScreen> createState() => _RegisterBioScreenState();
}

class _RegisterBioScreenState extends ConsumerState<RegisterBioScreen> {
  final TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final String? existingBio = ref.read(registrationProvider).profileData.bio;
    if (existingBio != null) _bioController.text = existingBio;
  }

  void _onNext() {
    ref.read(registrationProvider.notifier).updateProfileData(<String, dynamic>{
      'bio': _bioController.text.trim(),
    });
    context.push('/theme-selection');
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'register.bio_title'.tr(),
      progress: 9 / 9,
      onContinue: _onNext,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('register.bio_subtitle'.tr(), style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            TextFormField(
              controller: _bioController,
              decoration: InputDecoration(
                hintText: 'register.bio_hint'.tr(),
              ),
              maxLines: 5,
              maxLength: 280,
            ),
          ],
        ),
      ),
    );
  }
}