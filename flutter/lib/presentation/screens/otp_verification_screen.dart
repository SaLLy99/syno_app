import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import 'package:syno_app/data/services/auth_service.dart';
import 'package:syno_app/presentation/providers/auth_service_provider.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/screens/theme.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/data/services/otp_verification_args.dart';
import 'package:syno_app/theme.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final OtpVerificationArgs args;

  const OtpVerificationScreen({super.key, required this.args});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  String _otpCode = "";
  bool _isLoading = false;

  // Custom Popup Helper
  Future<void> _showStatusDialog({
    required String title,
    required String message,
    bool isError = false,
  }) async {
    if (!mounted) return;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.redAccent : Colors.greenAccent,
              size: 64,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('dialog.ok'.tr(), style: const TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _verifyOtp() async {
    // Local validation
    if (_otpCode.length != 6) {
      _showStatusDialog(
        title: 'dialog.error_title'.tr(),
        message: 'otp.invalid_code'.tr(),
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final response = await authService.verifyOtp(
        email: widget.args.isEmail ? widget.args.identifier : null,
        phoneNumber: widget.args.isEmail ? null : widget.args.identifier, otpCode: _otpCode);

      if (response['is_registered']) {
        // User is fully registered. Store token and refresh profile.
        if (response['access_token'] != null) {
          await ref.read(currentUserProvider.notifier).setUser(null, token: response['access_token']);
          ref.invalidate(currentUserProvider);
        }

        await _showStatusDialog(
          title: 'login.success_title'.tr(),
          message: 'login.success_message'.tr(),
        );
        if (mounted) context.go('/profile');
      } else {
        // User exists but has no profile, or is a brand new user.
        if (response['access_token'] != null) {
           // Store token so the router recognizes the authenticated session
           await ref.read(currentUserProvider.notifier).setUser(null, token: response['access_token']);
        }

        // Seed registration provider so the router guard allows entry to Step 2
        final key = widget.args.isEmail ? 'email' : 'phone_number';
        ref.read(registrationProvider.notifier).updateStep1Data({
          key: widget.args.identifier
        });
        
        // Invalidate registration provider to trigger router update
        ref.invalidate(registrationProvider);
        
        await _showStatusDialog(
          title: 'otp.verify_title'.tr(),
          message: 'register.welcome_message'.tr(),
        );

        if (mounted) context.go('/register-step2');
      }
    } catch (e) {
      // Extract translation key and localize it
      final errorKey = e.toString().replaceFirst('Exception: ', '').trim();
      await _showStatusDialog(
        title: 'dialog.error_title'.tr(),
        message: errorKey.tr(),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final lang = context.locale.languageCode;
      await authService.requestOtp(
        email: widget.args.isEmail ? widget.args.identifier : null,
        phoneNumber: widget.args.isEmail ? null : widget.args.identifier, lang: lang);
      await _showStatusDialog(
        title: 'otp.otp_subject'.tr(),
        message: 'otp.otp_message'.tr(namedArgs: {'code': '...', 'minutes': '10'}),
      );
    } catch (e) {
      final errorKey = e.toString().replaceFirst('Exception: ', '');
      await _showStatusDialog(
        title: 'otp.rate_limit_error'.tr(),
        message: errorKey.tr(),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('otp.verify_title'.tr()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.args.isEmail
                  ? 'otp.verify_message'.tr(args: [widget.args.identifier])
                  : 'otp.verify_message_phone'.tr(namedArgs: {'phone_number': widget.args.identifier}),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Stack(
              alignment: Alignment.center,
              children: [
                OtpTextField(
                  numberOfFields: 6,
                  borderColor: Colors.white,
                  focusedBorderColor: Theme.of(context).colorScheme.primary,
                  showFieldAsBox: true,
                  fillColor: Colors.white,
                  filled: true,
                  borderRadius: BorderRadius.circular(12),
                  borderWidth: 1.0,
                  fieldWidth: 46.0,
                  // Text must be dark since the background is now white
                  textStyle: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  onCodeChanged: (String code) => _otpCode = code,
                  onSubmit: (String verificationCode) {
                    _otpCode = verificationCode;
                    _verifyOtp();
                  },
                ),
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      "-",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black.withOpacity(0.2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'otp.paste_tip'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.md),
                child: Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: _isLoading ? null : _resendOtp,
              child: Text(
                'otp.resend_code'.tr(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}