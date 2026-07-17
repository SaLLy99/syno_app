import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import 'package:syno_app/data/services/auth_service.dart';
import 'package:syno_app/presentation/providers/auth_service_provider.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/data/services/otp_verification_args.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/presentation/utils/error_localization.dart';

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
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
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
        actions: <Widget>[
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
      final AuthService authService = ref.read(authServiceProvider);
      final Map<String, dynamic> response = await authService.verifyOtp(
        email: widget.args.isEmail ? widget.args.identifier : null,
        phoneNumber: widget.args.isEmail ? null : widget.args.identifier, otpCode: _otpCode);

      final String? token = response['access_token'];
      final bool isRegistered = response['is_registered'] ?? false;

      // 1. Seed registration data if the user is new
      if (!isRegistered) {
        final String key = widget.args.isEmail ? 'email' : 'phone_number';
        ref.read(registrationProvider.notifier).updateStep1Data(<String, String>{
          key: widget.args.identifier
        });
      }

      // 2. Show success dialog and wait for user acknowledgment
      await _showStatusDialog(
        title: isRegistered ? 'login.success_title'.tr() : 'otp.verification_success_title'.tr(),
        message: isRegistered ? 'login.success_message'.tr() : 'otp.verification_success_message'.tr(),
      );

      if (!mounted) return;

      // 3. Update auth state and fetch profile. 
      // Using refreshUser(token) ensures the state stays in 'loading' until the fetch is complete,
      // preventing the router from jumping to the wrong screen prematurely.
      if (token != null) {
        await ref.read(currentUserProvider.notifier).refreshUser(token: token);
      }

      if (!mounted) return;
      if (isRegistered) {
        context.go('/discover');
      } else {
        context.go('/register-name');
      }
    } catch (e) {
      final String message = resolveLocalizedMessage(e.toString());
      await _showStatusDialog(
        title: 'dialog.error_title'.tr(),
        message: message,
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);
    try {
      final AuthService authService = ref.read(authServiceProvider);
      final String lang = context.locale.languageCode;
      await authService.requestOtp(
        email: widget.args.isEmail ? widget.args.identifier : null,
        phoneNumber: widget.args.isEmail ? null : widget.args.identifier, lang: lang);
      await _showStatusDialog(
        title: 'otp.otp_subject'.tr(),
        message: 'otp.otp_message'.tr(namedArgs: <String, String>{'code': '...', 'minutes': '10'}),
      );
    } catch (e) {
      final String message = resolveLocalizedMessage(e.toString());
      await _showStatusDialog(
        title: 'otp.rate_limit_error'.tr(),
        message: message,
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
        title: Text('otp.enter_code_title'.tr()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.args.isEmail
                  ? 'otp.verify_message'.tr(args: <String>[widget.args.identifier])
                  : 'otp.verify_message_phone'.tr(namedArgs: <String, String>{'phone_number': widget.args.identifier}),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
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