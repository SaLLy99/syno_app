import 'package:flutter/material.dart';
import 'package:syno_app/presentation/screens/legal_screen.dart';


class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScreen(
      titleKey: 'legal.privacy.title',
      contentKey: 'legal.privacy.content',
    );
  }
}