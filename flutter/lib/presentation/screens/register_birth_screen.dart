import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/providers/location_providers.dart';
import 'package:syno_app/presentation/widgets/onboarding_scaffold.dart';
import 'package:syno_app/domain/entities/location_item.dart';

class RegisterBirthScreen extends ConsumerStatefulWidget {
  const RegisterBirthScreen({super.key});

  @override
  ConsumerState<RegisterBirthScreen> createState() =>
      _RegisterBirthScreenState();
}

class _RegisterBirthScreenState extends ConsumerState<RegisterBirthScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _birthTimeController = TextEditingController();
  final TextEditingController _birthLocationController = TextEditingController();

  LocationItem? _selectedLocation;

  @override
  void initState() {
    super.initState();
    final ProfileData regState = ref.read(registrationProvider).profileData;
    if (regState.birthDate != null) {
      _birthDateController.text = regState.birthDate.toString();
    }
    if (regState.birthTime != null) {
      _birthTimeController.text = regState.birthTime!;
    }
  }

  @override
  void dispose() {
    _birthDateController.dispose();
    _birthTimeController.dispose();
    _birthLocationController.dispose();
    super.dispose();
  }

  void _onContinue() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('register.errors.birth_location_required'.tr())),
        );
        return;
      }

      ref.read(registrationProvider.notifier).updateProfileData(<String, dynamic>{
        'birth_date': _birthDateController.text,
        'birth_time': _birthTimeController.text,
        'location_id': _selectedLocation!.id,
      });

      context.push('/register-intentions'); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'register.natal_chart_title'.tr(),
      progress: 4 / 9,
      onContinue: _onContinue,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Date of Birth
              TextFormField(
                controller: _birthDateController,
                readOnly: true,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'register.dob_label'.tr(),
                  hintText: 'register.dob_hint'.tr(),
                  suffixIcon:
                      const Icon(Icons.calendar_today, color: Colors.white70),
                ),
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(2000),
                    firstDate: DateTime(1920),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _birthDateController.text =
                          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                    });
                  }
                },
                validator: (String? value) => (value == null || value.isEmpty)
                    ? 'register.errors.dob_required'.tr()
                    : null,
              ),
              const SizedBox(height: 24),

              // Time of Birth
              TextFormField(
                controller: _birthTimeController,
                readOnly: true,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'register.tob_label'.tr(),
                  hintText: 'register.tob_hint'.tr(),
                  suffixIcon:
                      const Icon(Icons.access_time, color: Colors.white70),
                ),
                onTap: () async {
                  TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 12, minute: 0),
                  );
                  if (picked != null) {
                    setState(() {
                      _birthTimeController.text =
                          "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              // Birth Location (TypeAhead)
              TypeAheadField<LocationItem>(
                controller: _birthLocationController,
                suggestionsCallback: (String pattern) async {
                  return await ref
                      .read(locationServiceProvider)
                      .searchLocations(pattern);
                },
                itemBuilder: (BuildContext context, LocationItem location) {
                  return ListTile(
                    title: Text(location.localizedDisplayName,
                        style: const TextStyle(color: Colors.white)),
                    tileColor: const Color(0xFF1A1A1A),
                  );
                },
                emptyBuilder: (BuildContext context) => Container(
                  color: const Color(0xFF1A1A1A),
                  child: ListTile(
                    title: Text('register.no_cities_found'.tr(),
                        style: const TextStyle(color: Colors.white70)),
                  ),
                ),
                loadingBuilder: (BuildContext context) => Container(
                  color: const Color(0xFF1A1A1A),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(color: Colors.white70),
                    ),
                  ),
                ),
                onSelected: (LocationItem location) {
                  setState(() {
                    _birthLocationController.text = location.localizedDisplayName;
                    _selectedLocation = location;
                  });
                },
                builder: (BuildContext context, TextEditingController controller, FocusNode focusNode) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'register.birth_location_label'.tr(),
                      hintText: 'register.birth_location_hint'.tr(),
                    ),
                    validator: (String? value) => (value == null || value.isEmpty)
                        ? 'register.errors.birth_location_required'.tr()
                        : null,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
