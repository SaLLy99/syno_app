import 'package:flutter/material.dart';
import 'package:syno_app/presentation/screens/legal_screen.dart';


class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScreen(
      titleKey: 'legal.terms.title',
      contentKey: 'legal.terms.content',
    );
  }
}