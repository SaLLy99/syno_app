import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';

class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(themeProvider);
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: appTheme.gradient,
          color: appTheme.gradient == null ? Colors.black : null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              
              // A. Logo
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(color: Colors.white24, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: Image.asset(
                    'assets/icons/dreamflow_icon.jpg',
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.auto_awesome,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // B. Slogan
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'landing.slogan'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: appTheme.primaryTextColor,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              
              const Spacer(flex: 3),
              
              // C. Language Selector
              const _LanguageSelector(),
              
              const SizedBox(height: 48),
              
              // D. CTA Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () => context.push('/login-method'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'landing.cta'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // E. Legal Text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                child: _LegalText(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale;
    
    return GestureDetector(
      onTap: () => _showLanguagePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
             _GeometricFlag(flag: _getFlag(currentLocale.languageCode), size: 32),
             const SizedBox(width: 16),
             Text(
               _getLanguageName(currentLocale.languageCode),
               style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
             ),
             const SizedBox(width: 4),
             const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageOption(locale: const Locale('en'), name: 'English', flag: '🇬🇧'),
            _LanguageOption(locale: const Locale('ru'), name: 'Русский', flag: '🇷🇺'),
            _LanguageOption(locale: const Locale('ka'), name: 'ქართული', flag: '🇬🇪'),
          ],
        ),
      ),
    );
  }
  
  String _getFlag(String code) {
    switch(code) {
      case 'en': return '🇬🇧';
      case 'ru': return '🇷🇺';
      case 'ka': return '🇬🇪';
      default: return '🌐';
    }
  }

  String _getLanguageName(String code) {
    switch(code) {
      case 'en': return 'English';
      case 'ru': return 'Русский';
      case 'ka': return 'ქართული';
      default: return 'Language';
    }
  }
}

class _GeometricFlag extends StatelessWidget {
  final String flag;
  final double size;
  const _GeometricFlag({required this.flag, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Text(
      flag,
      style: TextStyle(fontSize: size),
    );
  }
}

class _LegalText extends StatelessWidget {
  const _LegalText();

  @override
  Widget build(BuildContext context) {
    // Accessing keys directly here ensures reactivity when context.locale changes
    final fullText = 'landing.legal_full'.tr();
    final termsText = 'landing.terms'.tr();
    final privacyText = 'landing.privacy'.tr();

    final parts = fullText.split('{terms}');
    final secondPart = parts.length > 1 ? parts[1].split('{privacy}') : [];

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.6),
        children: [
          TextSpan(text: parts[0]),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => context.push('/terms'),
              child: Text(
                termsText,
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.w600, 
                  decoration: TextDecoration.underline
                ),
              ),
            ),
          ),
          if (secondPart.isNotEmpty) TextSpan(text: secondPart[0]),
          if (secondPart.length > 1) 
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                onTap: () => context.push('/privacy'),
                child: Text(
                  privacyText,
                  style: const TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.w600, 
                    decoration: TextDecoration.underline
                  ),
                ),
              ),
            ),
          if (secondPart.length > 1) TextSpan(text: secondPart[1]),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final Locale locale;
  final String name;
  final String flag;

  const _LanguageOption({required this.locale, required this.name, required this.flag});

  @override
  Widget build(BuildContext context) {
    final isSelected = context.locale == locale;
    return ListTile(
      onTap: () {
        context.setLocale(locale);
        Navigator.pop(context);
      },
      leading: _GeometricFlag(flag: flag),
      title: Text(
        name,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.white) : null,
    );
  }
}