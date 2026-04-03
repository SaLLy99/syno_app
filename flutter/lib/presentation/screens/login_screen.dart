import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/widgets/cosmic_gradient_button.dart';
import 'package:syno_app/presentation/widgets/cosmic_input_field.dart';
import 'package:syno_app/presentation/widgets/app_dialogs.dart'; 
import 'package:flutter/gestures.dart';
import 'dart:math';
 
class WavingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double waveAmplitude;
  final Duration waveDuration;

  const WavingText(
    this.text, {
    super.key,
    this.style,
    this.waveAmplitude = 3.0,
    this.waveDuration = const Duration(seconds: 4),
  });

  @override
  State<WavingText> createState() => _WavingTextState();
}

class _WavingTextState extends State<WavingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.waveDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Wrap(
          alignment: WrapAlignment.center,
          children: List.generate(widget.text.length, (index) {
            final character = widget.text[index];
            final double sinValue = sin((_controller.value * 2 * pi) + (index * 0.4));

            return Transform.translate(
              offset: Offset(0, sinValue * widget.waveAmplitude),
              child: Text(character, style: widget.style),
            );
          }),
        );
      },
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  void _login() async {
    if (_formKey.currentState!.validate() && !_isLoading) {
      setState(() => _isLoading = true);
      
      try {
        await ref.read(authProvider.notifier).login(
          _emailController.text,
          _passwordController.text,
        );
    
        if (!mounted) return;

        ref.invalidate(currentUserProvider);

        if (mounted) {
          AppDialogs.showSuccessDialog(
            context, 
            'login.success_title'.tr(), 
            'login.success_message'.tr(),
            onDismiss: () {
            },
          );
        }
      } catch (e) {
        if (mounted) {
          AppDialogs.showErrorDialog(
            context, 
            "Error",
            e.toString().replaceFirst("Exception: ", "")
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _loginWithFacebook() {
    // TODO: Implement Facebook authentication logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('login.redirecting_to_facebook'.tr())),
    );
  }

  void _loginWithMobile() {
    // TODO: Implement mobile number authentication logic (e.g., navigate to a new screen for phone number input and OTP)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('login.redirecting_to_mobile'.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: CosmicColors.deepSpaceGradient),
        child: Stack( // Using a Stack to overlay the loading indicator
        children: <Widget>[
            // Radial highlight
          Positioned(
            top: 120,
            left: 0,
            right: 0,
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: <Color>[
                    const Color(0xFFDB2777).withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Login UI
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Logo Card with Glow and Float Animation
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: CosmicColors.cosmicPink.withOpacity(0.3),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icons/dreamflow_icon.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Tagline with subtle glow
                    Text(
                      'login.title'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: CosmicColors.starlight.withOpacity(0.8),
                        letterSpacing: 1.5,
                        shadows: <Shadow>[
                          Shadow(
                            color: CosmicColors.cosmicPink.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    // Email Input Field
                    CosmicInputField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      hintText: 'login.email_hint'.tr(),
                      prefixIcon: Icons.mail_outline,
                      validator: (String? value) {
                        if (value == null || value.isEmpty) return 'login.email_required'.tr();
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Password Input Field
                    CosmicInputField(
                      controller: _passwordController,
                      obscureText: true,
                      hintText: 'login.password_hint'.tr(),
                      prefixIcon: Icons.lock_outline,
                      validator: (String? value) {
                        if (value == null || value.isEmpty) return 'login.password_required'.tr();
                        return null;
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // TODO: Implement forgot password logic
                        },
                        child: Text(
                          'login.forgot_password'.tr(),
                          style: context.textStyles.bodySmall?.withColor(CosmicColors.cosmicPink),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Login Button
                    CosmicGradientButton(
                      onPressed: _login,
                      borderRadius: BorderRadius.circular(AppRadius.xl), // Rounded-full equivalent
                      height: 60, // py-4 is roughly 16px padding, so height 50-60
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: CosmicColors.cosmicPurple.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      child: _isLoading
                          ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                          : Text('login.login_button'.tr(), style: context.textStyles.labelLarge?.semiBold.withColor(Colors.white)),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(children: <Widget>[
                      const Expanded(child: Divider(color: CosmicColors.borderColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        child: Text(
                          "login.or_divider".tr(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CosmicColors.mutedForeground),
                        ),
                      ),
                      const Expanded(child: Divider(color: CosmicColors.borderColor))
                    ]),
                    const SizedBox(height: AppSpacing.lg),
                    // Facebook Button
                    GestureDetector(
                      onTap: _loginWithFacebook, // Keep interaction handlers first
                      child: Container( // The child widget
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: <Color>[CosmicColors.cosmicBlue, CosmicColors.cosmicPurple], // Blue to Purple gradient
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: CosmicColors.cosmicBlue.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Icon(Icons.facebook, color: Colors.white),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'login.continue_with_facebook'.tr(),
                              style: context.textStyles.labelLarge?.semiBold.withColor(Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Mobile Button
                    ElevatedButton.icon(
                      icon: const Icon(Icons.phone_android, color: Colors.white),
                      label: Text(
                        'login.continue_with_mobile'.tr(),
                        style: context.textStyles.labelLarge?.semiBold.withColor(Colors.white),
                      ),
                      onPressed: _loginWithMobile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                        backgroundColor: CosmicColors.nebulaPurple.withOpacity(0.8),
                        shadowColor: CosmicColors.nebulaPurple.withOpacity(0.3),
                        elevation: 8,
                      ).copyWith(
                        overlayColor: WidgetStateProperty.all(CosmicColors.nebulaPurple.withOpacity(0.2)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Sign Up Link
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CosmicColors.mutedForeground),
                        children: <InlineSpan>[
                          TextSpan(
                            text: 'Sign up',
                            style: context.textStyles.bodyMedium?.semiBold.withColor(CosmicColors.cosmicPink),
                            recognizer: TapGestureRecognizer()..onTap = () => context.go('/register'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}