import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/screens/theme.dart';

class RegisterModeScreen extends ConsumerStatefulWidget {
  const RegisterModeScreen({super.key});

  @override
  ConsumerState<RegisterModeScreen> createState() => _RegisterModeScreenState();
}

class _RegisterModeScreenState extends ConsumerState<RegisterModeScreen> {
  String? _selectedMode;

  void _onContinue() {
    if (_selectedMode == null) return;
    ref.read(registrationProvider.notifier).updateProfileData(<String, dynamic>{
      'active_mode': _selectedMode,
    });
    context.push('/register-identity');
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth > 600;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'register.mode_title'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: CosmicColors.deepSpaceGradient),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 2 / 10),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    builder: (BuildContext context, double animatedProgress, Widget? child) {
                      return LinearProgressIndicator(
                        value: animatedProgress,
                        backgroundColor: Colors.white10,
                        color: CosmicColors.cosmicPink,
                        minHeight: 6,
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: <Widget>[
                      const SizedBox(height: 24),
                      Text(
                        'register.mode_subtitle'.tr(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Expanded(
                        child: isWide
                            ? Row(
                                children: <Widget>[
                                  Expanded(child: _buildDatingCard()),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildBffCard()),
                                ],
                              )
                            : Column(
                                children: <Widget>[
                                  Expanded(child: _buildDatingCard()),
                                  const SizedBox(height: 16),
                                  Expanded(child: _buildBffCard()),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedMode != null ? _onContinue : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: _selectedMode != null
                          ? CosmicColors.cosmicPink
                          : Colors.grey.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'register.continue'.tr(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatingCard() {
    final bool isSelected = _selectedMode == 'dating';
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = 'dating'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFDB2777) : Colors.white24,
            width: isSelected ? 3 : 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? <Color>[const Color(0xFFDB2777).withOpacity(0.3), const Color(0xFF9333EA).withOpacity(0.2)]
                : <Color>[Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFDB2777).withOpacity(0.2),
                ),
                child: const Text('\u{1F494}', style: TextStyle(fontSize: 40)),
              ),
              const SizedBox(height: 16),
              Text(
                'Dating',
                style: TextStyle(
                  color: isSelected ? const Color(0xFFDB2777) : Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'register.mode_dating_desc'.tr(),
                style: const TextStyle(color: Colors.white60, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              if (isSelected) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDB2777).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '\u2713 Selected',
                    style: TextStyle(color: Color(0xFFDB2777), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBffCard() {
    final bool isSelected = _selectedMode == 'bff';
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = 'bff'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A90D9) : Colors.white24,
            width: isSelected ? 3 : 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? <Color>[const Color(0xFF4A90D9).withOpacity(0.3), const Color(0xFF06B6D4).withOpacity(0.2)]
                : <Color>[Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4A90D9).withOpacity(0.2),
                ),
                child: const Text('\u{1F91D}', style: TextStyle(fontSize: 40)),
              ),
              const SizedBox(height: 16),
              Text(
                'BFF',
                style: TextStyle(
                  color: isSelected ? const Color(0xFF4A90D9) : Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'register.mode_bff_desc'.tr(),
                style: const TextStyle(color: Colors.white60, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              if (isSelected) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90D9).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '\u2713 Selected',
                    style: TextStyle(color: Color(0xFF4A90D9), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
