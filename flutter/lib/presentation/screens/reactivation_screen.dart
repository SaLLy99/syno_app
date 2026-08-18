import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/presentation/utils/error_localization.dart';

class ReactivationScreen extends ConsumerStatefulWidget {
  const ReactivationScreen({super.key});

  @override
  ConsumerState<ReactivationScreen> createState() => _ReactivationScreenState();
}

class _ReactivationScreenState extends ConsumerState<ReactivationScreen> {
  final TextEditingController _identifierController = TextEditingController();
  String _otpCode = "";
  bool _isLoading = false;
  bool _codeSent = false;
  bool _identifierValid = false;
  bool _isPhoneMode = false;

  Map<String, String> _selectedCountry = <String, String>{'name': 'Georgia', 'code': '+995', 'flag': '🇬🇪'};

  final List<Map<String, String>> _countries = <Map<String, String>>[
    <String, String>{'name': 'Georgia', 'code': '+995', 'flag': '🇬🇪'},
    <String, String>{'name': 'Russia', 'code': '+7', 'flag': '🇷🇺'},
    <String, String>{'name': 'United States', 'code': '+1', 'flag': '🇺🇸'},
    <String, String>{'name': 'United Kingdom', 'code': '+44', 'flag': '🇬🇧'},
  ];

  final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  final RegExp _phoneRegex = RegExp(r'^[0-9]{7,15}$');

  String _maskIdentifier(String value) {
    if (_isPhoneMode) {
      if (value.length <= 6) return value;
      return '${value.substring(0, 5)}***${value.substring(value.length - 3)}';
    } else {
      final parts = value.split('@');
      if (parts.length != 2) return value;
      final name = parts[0];
      final domain = parts[1];
      if (name.length <= 3) return '***@$domain';
      return '${name.substring(0, 3)}${'*' * (name.length - 3)}@$domain';
    }
  }

  void _validateIdentifier(String value) {
    setState(() {
      final String trimmed = value.trim();
      if (_isPhoneMode) {
        _identifierValid = _phoneRegex.hasMatch(trimmed);
      } else {
        _identifierValid = _emailRegex.hasMatch(trimmed);
      }
    });
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _countries.length,
          itemBuilder: (BuildContext context, int index) => ListTile(
            leading: Text(_countries[index]['flag']!, style: const TextStyle(fontSize: 28)),
            title: Text(_countries[index]['name']!, style: const TextStyle(color: Colors.white)),
            trailing: Text(_countries[index]['code']!, style: const TextStyle(color: Colors.cyanAccent)),
            onTap: () {
              setState(() => _selectedCountry = _countries[index]);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _isPhoneMode = !_isPhoneMode;
      _identifierController.clear();
      _identifierValid = false;
      _codeSent = false;
      _otpCode = "";
    });
  }

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

  Future<void> _requestReactivationCode() async {
    if (!_identifierValid) return;
    setState(() => _isLoading = true);
    try {
      final String raw = _identifierController.text.trim();
      final String value = _isPhoneMode ? '${_selectedCountry['code']}$raw' : raw;
      if (_isPhoneMode) {
        await ref.read(currentUserProvider.notifier).requestReactivation(phoneNumber: value);
      } else {
        await ref.read(currentUserProvider.notifier).requestReactivation(email: value);
      }
      setState(() => _codeSent = true);
      final String masked = _maskIdentifier(value);
      final String messageKey = _isPhoneMode
          ? 'reactivation.code_sent_message_phone'
          : 'reactivation.code_sent_message_email';
      await _showStatusDialog(
        title: 'reactivation.code_sent_title'.tr(),
        message: messageKey.tr(args: <String>[masked]),
      );
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

  Future<void> _verifyReactivationCode() async {
    if (_otpCode.length != 6) {
      await _showStatusDialog(
        title: 'dialog.error_title'.tr(),
        message: 'otp.invalid_code'.tr(),
        isError: true,
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final String raw = _identifierController.text.trim();
      final String value = _isPhoneMode ? '${_selectedCountry['code']}$raw' : raw;
      if (_isPhoneMode) {
        await ref.read(currentUserProvider.notifier).verifyReactivation(
          phoneNumber: value,
          code: _otpCode,
        );
      } else {
        await ref.read(currentUserProvider.notifier).verifyReactivation(
          email: value,
          code: _otpCode,
        );
      }
      await _showStatusDialog(
        title: 'reactivation.success_title'.tr(),
        message: 'reactivation.success_message'.tr(),
      );
      // Clear any stale registration data so the router doesn't redirect to registration
      ref.read(registrationProvider.notifier).reset();
      if (mounted) {
        context.go('/discover');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('reactivation.title'.tr()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(Icons.replay, size: 64, color: Colors.cyanAccent),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'reactivation.subtitle'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!_codeSent) ...<Widget>[
              // Toggle between email and phone
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'reactivation.use_email'.tr(),
                    style: TextStyle(
                      color: !_isPhoneMode ? Colors.cyanAccent : Colors.white54,
                      fontWeight: !_isPhoneMode ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Switch(
                    value: _isPhoneMode,
                    onChanged: (_) => _toggleMode(),
                    activeColor: Colors.cyanAccent,
                  ),
                  Text(
                    'reactivation.use_phone'.tr(),
                    style: TextStyle(
                      color: _isPhoneMode ? Colors.cyanAccent : Colors.white54,
                      fontWeight: _isPhoneMode ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (_isPhoneMode)
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      GestureDetector(
                        onTap: _showCountryPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(_selectedCountry['flag']!, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 8),
                              Text(_selectedCountry['code']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 20),
                              const SizedBox(width: 8),
                              Container(width: 1, height: 24, color: Colors.white12),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _identifierController,
                          onChanged: _validateIdentifier,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          keyboardType: TextInputType.phone,
                          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            hintText: 'reactivation.phone_hint'.tr(),
                            hintStyle: const TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                TextField(
                  controller: _identifierController,
                  onChanged: _validateIdentifier,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'login.email_hint'.tr(),
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.alternate_email, color: Colors.cyanAccent),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_identifierValid && !_isLoading) ? _requestReactivationCode : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    disabledBackgroundColor: Colors.white10,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        'reactivation.send_code'.tr(),
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
            ] else ...<Widget>[
              Text(
                'reactivation.enter_code'.tr(args: <String>[
                  _isPhoneMode
                      ? '${_selectedCountry['code']}${_identifierController.text.trim()}'
                      : _identifierController.text.trim(),
                ]),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
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
                textStyle: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                onCodeChanged: (String code) => _otpCode = code,
                onSubmit: (String verificationCode) {
                  _otpCode = verificationCode;
                  _verifyReactivationCode();
                },
              ),
              const SizedBox(height: AppSpacing.md),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: _isLoading ? null : _requestReactivationCode,
                child: Text(
                  'otp.resend_code'.tr(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_otpCode.length == 6 && !_isLoading) ? _verifyReactivationCode : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    disabledBackgroundColor: Colors.white10,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        'reactivation.reactivate'.tr(),
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
