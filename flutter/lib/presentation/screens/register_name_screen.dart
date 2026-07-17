import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/widgets/onboarding_scaffold.dart';

class RegisterNameScreen extends ConsumerStatefulWidget {
  const RegisterNameScreen({super.key});

  @override
  ConsumerState<RegisterNameScreen> createState() => _RegisterNameScreenState();
}

class _RegisterNameScreenState extends ConsumerState<RegisterNameScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill data if user is returning to this step
    final ProfileData regState = ref.read(registrationProvider).profileData;
    if (regState.name != null) _nameController.text = regState.name.toString();
    if (regState.lastName != null) _lastNameController.text = regState.lastName.toString();
    if (regState.height != null) _heightController.text = regState.height.toString();
  }

  void _showHeightPicker() {
    int initialValue = int.tryParse(_heightController.text) ?? 170;
    if (initialValue < 50 || initialValue > 300) initialValue = 170;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (BuildContext context) {
        return SizedBox(
          height: 250,
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  CupertinoButton(
                    child: Text('register.done'.tr(), style: const TextStyle(color: Colors.white)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: const Color(0xFF1A1A1A),
                  itemExtent: 32.0,
                  scrollController: FixedExtentScrollController(initialItem: initialValue - 50),
                  onSelectedItemChanged: (int index) {
                    setState(() => _heightController.text = (index + 50).toString());
                  },
                  children: List<Widget>.generate(251, (int index) {
                    return Center(
                      child: Text('${index + 50} cm', style: const TextStyle(color: Colors.white)),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onContinue() {
    if (_formKey.currentState?.validate() ?? false) {
      double? heightValue = double.tryParse(_heightController.text.replaceAll(',', '.'));
      int? heightInCm;
      
      if (heightValue != null) {
        heightInCm = (heightValue < 3.0) ? (heightValue * 100).round() : heightValue.round();
      }

      ref.read(registrationProvider.notifier).updateProfileData(<String, dynamic>{
        'name': _nameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'height': heightInCm,
      });

      context.push('/register-photos'); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'register.name_title'.tr(),
      progress: 1 / 9,
      onContinue: _onContinue,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'register.name'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 32),
              
              // Name Field
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'register.name'.tr(), // Added label
                  hintText: 'register.name'.tr(),
                  hintStyle: const TextStyle(color: Colors.white24),
                ),
                validator: (String? value) => (value == null || value.trim().isEmpty) 
                    ? 'register.errors.name_required'.tr() 
                    : null,
                autofocus: true,
              ),
              const SizedBox(height: 24),

              // Last Name Field
              TextFormField(
                controller: _lastNameController,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'register.last_name'.tr(),
                  hintText: 'register.last_name'.tr(),
                ),
              ),
              const SizedBox(height: 24),

              // Height Field
              TextFormField(
                controller: _heightController,
                readOnly: true,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'register.height'.tr(),
                  suffixIcon: const Icon(Icons.height, color: Colors.white70),
                ),
                onTap: _showHeightPicker,
                validator: (String? value) => (value == null || value.isEmpty) 
                    ? 'register.errors.height_required'.tr() 
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}