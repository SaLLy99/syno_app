import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/data/services/otp_verification_args.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/data/services/auth_service.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/widgets/app_dialogs.dart';

class LoginMethodScreen extends ConsumerStatefulWidget {
  const LoginMethodScreen({super.key});

  @override
  ConsumerState<LoginMethodScreen> createState() => _LoginMethodScreenState();
}

class _LoginMethodScreenState extends ConsumerState<LoginMethodScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isEmailSelected = true;
  bool _isEmailValid = false;
  bool _isPhoneNumberSelected = false;
  bool _isPhoneNumberValid = false;
  bool _isLoading = false;
  
  Map<String, String> _selectedCountry = {'name': 'Georgia', 'code': '+995', 'flag': '🇬🇪'};

  final List<Map<String, String>> _countries = [
    {'name': 'Georgia', 'code': '+995', 'flag': '🇬🇪'},
    {'name': 'Russia', 'code': '+7', 'flag': '🇷🇺'},
    {'name': 'United States', 'code': '+1', 'flag': '🇺🇸'},
    {'name': 'United Kingdom', 'code': '+44', 'flag': '🇬🇧'},
  ];

  final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _validateEmail(String value) {
    setState(() {
      _isEmailValid = _emailRegex.hasMatch(value.trim());
    });
  }

  void _validatePhoneNumber(String value) {
      final trimmedValue = value.trim();
      
      final phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');

      setState(() {
        _isPhoneNumberValid = phoneRegex.hasMatch(trimmedValue);
  });
}

  void _showCountryPicker(AppThemeData appTheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Color(0xFF1A1A1A), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: ListView.builder(
        shrinkWrap: true,
        itemCount: _countries.length,
        itemBuilder: (context, index) => ListTile(
          leading: _buildGeometricFlag(_countries[index]['flag']!, size: 28),
          title: Text(_countries[index]['name']!, style: const TextStyle(color: Colors.white)),
          trailing: Text(_countries[index]['code']!, style: const TextStyle(color: Colors.cyanAccent)),
          onTap: () {
            setState(() => _selectedCountry = _countries[index]);
            Navigator.pop(context);
          },
        ),
      ),)
    );
  }

 Future<void> _handleContinue() async {
  // 1. Validation Check
  if ((_isEmailSelected && !_isEmailValid) || (_isPhoneNumberSelected && !_isPhoneNumberValid)) return;

  setState(() => _isLoading = true);
  
  try {
    final authService = ref.read(authServiceProvider);
    final lang = context.locale.languageCode;
    
    // Determine the identifier and mode
    final String identifier = _isEmailSelected 
        ? _emailController.text.trim() 
        : '${_selectedCountry['code']}${_phoneController.text.trim()}';

    // 2. Call the API
    if (_isEmailSelected) {
      // Save identifier to mark registration in progress for the router
      ref.read(registrationProvider.notifier).updateStep1Data({
        'email': identifier,
        'phone_number': '',
      });
      
      await authService.requestOtp(email: identifier, lang: lang);
    } else {
      // For phone registration flow, save the phone number as the primary
      // registration identifier so the router knows this flow is active.
      ref.read(registrationProvider.notifier).updateStep1Data({
        'phone_number': identifier,
        'email': '',
      });
      
      await authService.requestOtp(phoneNumber: identifier, lang: lang);
    }
    
    // 3. Navigate with the correct object type
    if (mounted) {
      context.push(
        '/otp-verification', 
        extra: OtpVerificationArgs(
          identifier: identifier,
          isEmail: _isEmailSelected,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      AppDialogs.showErrorDialog(context, 'dialog.error_title'.tr(), e.toString());
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: appTheme.gradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/landing');
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),
                
                // Improved Logo Design (Cleaner, consistent with Landing)
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                    image: const DecorationImage(
                      image: AssetImage('assets/icons/dreamflow_icon.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                // Sliding Toggle
                Container(
                  height: 54,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(27),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Stack(
                    children: [
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        alignment: _isEmailSelected ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          width: (MediaQuery.of(context).size.width - 64 - 8) / 2,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(23),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _toggleItem(
                            'login.email_toggle'.tr(), 
                            _isEmailSelected, 
                            () => setState(() {
                              _isEmailSelected = true;
                              _isPhoneNumberSelected = false; 
                            }),
                          ),

                          // Mobile Toggle
                          _toggleItem(
                            'login.mobile_toggle'.tr(), 
                            _isPhoneNumberSelected, 
                            () => setState(() {
                              _isEmailSelected = false; 
                              _isPhoneNumberSelected = true; 
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isEmailSelected ? _buildEmailField(appTheme) : _buildPhoneField(appTheme),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (!_isLoading && (_isEmailSelected ? _isEmailValid : _phoneController.text.isNotEmpty)) 
                        ? _handleContinue 
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white24,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : Text('register_main.continue_button'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const Spacer(flex: 2),
                Text(
                  'landing.legal_full'.tr(namedArgs: {'terms': 'landing.terms'.tr(), 'privacy': 'landing.privacy'.tr()}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggleItem(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.black : Colors.white,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField(AppThemeData appTheme) {
    return TextFormField(
      key: const ValueKey('email'),
      controller: _emailController,
      onChanged: _validateEmail,
      style: TextStyle(color: appTheme.primaryTextColor),
      decoration: InputDecoration(
        hintText: 'login.email_hint'.tr(),
        hintStyle: TextStyle(color: appTheme.secondaryTextColor.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white)),
        prefixIcon: Icon(Icons.email_outlined, color: appTheme.secondaryTextColor),
        suffixIcon: _isEmailValid ? const Icon(Icons.check_circle, color: Colors.white) : null,
      ),
    );
  }

  Widget _buildPhoneField(AppThemeData appTheme) {
    return Container(
      key: const ValueKey('phone'),
      height: 60, // Matches the approximate height of the email field
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => _showCountryPicker(appTheme),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGeometricFlag(_selectedCountry['flag']!, size: 22),
                  const SizedBox(width: 8),
                  Text(_selectedCountry['code']!, style: TextStyle(color: appTheme.primaryTextColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  Icon(Icons.keyboard_arrow_down_rounded, color: appTheme.secondaryTextColor, size: 20),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 24, color: Colors.white12), // Vertical divider
                ],
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              onChanged: _validatePhoneNumber,
              style: TextStyle(color: appTheme.primaryTextColor, fontSize: 16),
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'login.phone_hint'.tr(),
                hintStyle: TextStyle(color: appTheme.secondaryTextColor.withOpacity(0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeometricFlag(String flag, {double size = 22}) {
    return Text(
      flag,
      style: TextStyle(fontSize: size),
    );
  }
}