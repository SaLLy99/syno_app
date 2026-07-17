import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/presentation/providers/auth_service_provider.dart';
import 'package:syno_app/data/services/otp_verification_args.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/presentation/utils/error_localization.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isEmailActive = true;
  bool _isButtonEnabled = false;
  bool _isLoading = false;

  final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  // Simple regex for international phone numbers (e.g., +995555123456)
  final RegExp _phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');

  void _validateInput(String value) {
    setState(() {
      final String trimmedValue = value.trim();
      if (_isEmailActive) {
        _isButtonEnabled = _emailRegex.hasMatch(trimmedValue);
      } else {
        _isButtonEnabled = _phoneRegex.hasMatch(trimmedValue);
      }
    });
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);
    try {
      final String identifier = _isEmailActive 
          ? _emailController.text.trim() 
          : _phoneController.text.trim();
          
      final OtpVerificationArgs args = OtpVerificationArgs(identifier: identifier, isEmail: _isEmailActive);
      
      // Pass the current locale to the backend for localized email
      final String lang = context.locale.languageCode;
      await ref.read(authServiceProvider).requestOtp(
        email: _isEmailActive ? identifier : null,
        phoneNumber: !_isEmailActive ? identifier : null,
        lang: lang,
      );
      
      if (mounted) {
        context.push('/otp-verification', extra: args);
      }
    } catch (e) {
      final String message = resolveLocalizedMessage(e.toString(), context: context);
      showDialog(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('dialog.error_title'.tr(), style: const TextStyle(color: Colors.white)),
          content: Text(message, style: const TextStyle(color: Colors.white70)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('dialog.ok'.tr(), style: const TextStyle(color: Colors.cyanAccent)),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: CosmicColors.deepSpaceGradient),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // App Logo
              Image.asset('assets/icons/dreamflow_icon.jpg', height: 120),
              const SizedBox(height: 40),
              
              // Email/Phone Badge Toggles
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _buildBadge("login.email_toggle".tr(), _isEmailActive, () => setState(() => _isEmailActive = true)),
                  const SizedBox(width: 16),
                  _buildBadge("login.mobile_toggle".tr(), !_isEmailActive, () => setState(() => _isEmailActive = false)),
                ],
              ),
              const SizedBox(height: 32),

              if (_isEmailActive) ...<Widget>[
                TextField(
                  controller: _emailController,
                  onChanged: _validateInput,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: "login.email_hint".tr(),
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.alternate_email, color: Colors.cyanAccent),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                  ),
                ),
              ] else ...<Widget>[
                TextField(
                  controller: _phoneController,
                  onChanged: _validateInput,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: "login.phone_hint".tr(),
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.phone_android, color: Colors.cyanAccent),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                  ),
                ),
              ],
              
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isButtonEnabled && !_isLoading) ? _handleContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    disabledBackgroundColor: Colors.white10,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        "register_main.continue_button".tr(),
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
              
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => context.go('/register'),
                child: Text(
                  "login.signup_prompt".tr(),
                  style: const TextStyle(color: Colors.white70, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.cyanAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? Colors.cyanAccent : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}