import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/providers/location_providers.dart';
import 'package:syno_app/presentation/widgets/onboarding_scaffold.dart';
import 'package:syno_app/domain/entities/location_item.dart';
import 'package:syno_app/theme.dart';

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
        'astrology_system': 'western',
      });

      context.push('/register-intentions');
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'register.natal_chart_title'.tr(),
      progress: 5 / 10,
      onContinue: _onContinue,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'register.natal_chart_subtitle'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Date of Birth
              _buildFieldLabel('register.dob_label'.tr()),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
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
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11121A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.calendar_today,
                          color: Colors.white.withOpacity(0.5), size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _birthDateController.text.isNotEmpty
                            ? _birthDateController.text
                            : 'register.dob_hint'.tr(),
                        style: TextStyle(
                          color: _birthDateController.text.isNotEmpty
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Time of Birth
              _buildFieldLabel('register.tob_label'.tr()),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
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
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11121A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.access_time,
                          color: Colors.white.withOpacity(0.5), size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _birthTimeController.text.isNotEmpty
                            ? _birthTimeController.text
                            : 'register.tob_hint'.tr(),
                        style: TextStyle(
                          color: _birthTimeController.text.isNotEmpty
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Birth Location
              _buildFieldLabel('register.birth_location_label'.tr()),
              const SizedBox(height: 8),
              TypeAheadField<LocationItem>(
                controller: _birthLocationController,
                suggestionsCallback: (String pattern) async {
                  return await ref
                      .read(locationServiceProvider)
                      .searchLocations(pattern);
                },
                itemBuilder: (BuildContext context, LocationItem location) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    color: const Color(0xFF1A1A2E),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.location_on,
                            color: CosmicColors.cosmicPink.withOpacity(0.7),
                            size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(location.name,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14)),
                              if (location.parent != null)
                                Text(location.parent!.name,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
                emptyBuilder: (BuildContext context) => Container(
                  color: const Color(0xFF1A1A2E),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.search_off,
                          color: Colors.white.withOpacity(0.4), size: 18),
                      const SizedBox(width: 12),
                      Text('register.no_cities_found'.tr(),
                          style:
                              TextStyle(color: Colors.white.withOpacity(0.5))),
                    ],
                  ),
                ),
                loadingBuilder: (BuildContext context) => Container(
                  color: const Color(0xFF1A1A2E),
                  padding: const EdgeInsets.all(16),
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: Colors.white54, strokeWidth: 2),
                  ),
                ),
                onSelected: (LocationItem location) {
                  setState(() {
                    _birthLocationController.text =
                        location.localizedDisplayName;
                    _selectedLocation = location;
                  });
                },
                builder: (BuildContext context, TextEditingController controller,
                    FocusNode focusNode) {
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF11121A),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'register.birth_location_hint'.tr(),
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.4)),
                        prefixIcon: Icon(Icons.location_on,
                            color: Colors.white.withOpacity(0.5), size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon: controller.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    color: Colors.white.withOpacity(0.4),
                                    size: 18),
                                onPressed: () {
                                  controller.clear();
                                  setState(() => _selectedLocation = null);
                                },
                              )
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withOpacity(0.6),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
