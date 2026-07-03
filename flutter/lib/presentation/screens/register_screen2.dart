import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:syno_app/domain/entities/user.dart' hide Hobby, Sex;
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/location_providers.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/domain/entities/location_item.dart';
import 'package:syno_app/domain/entities/sexes_data.dart';
import 'package:syno_app/domain/entities/hobbies_data.dart';
import 'package:syno_app/domain/entities/orientations_data.dart';
import 'package:syno_app/domain/entities/profile_options.dart' hide CoreValue;
import 'package:syno_app/data/services/profession_service.dart';
import 'package:syno_app/data/services/education_service.dart';
import 'package:dio/dio.dart';

// Providers to fetch the dynamic options
final intentionsProvider = FutureProvider<List<Intention>>((ref) async {
  final backendUrl = ref.watch(backendUrlProvider);
  final response = await Dio().get('$backendUrl/api/intentions');
  return (response.data as List).map((i) => Intention.fromJson(i)).toList();
});

final coreValuesProvider = FutureProvider<List<CoreValue>>((ref) async {
  final backendUrl = ref.watch(backendUrlProvider);
  final response = await Dio().get('$backendUrl/api/core-values');
  return (response.data as List).map((cv) => CoreValue.fromJson(cv)).toList();
});

class RegisterScreen2 extends ConsumerStatefulWidget {
  final Map<String, dynamic>? data;
  const RegisterScreen2({super.key, this.data});

  @override
  _RegisterScreen2State createState() => _RegisterScreen2State();
}

class _RegisterScreen2State extends ConsumerState<RegisterScreen2> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _birthTimeController = TextEditingController();
  final TextEditingController _birthLocationController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _professionController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  List<ProfessionModel> _allProfessions = <ProfessionModel>[];
  List<EducationModel> _allEducations = <EducationModel>[];

  // Dropdown / chip selections
  int? _selectedGenderId;
  int? _selectedOrientationId;
  final Set<int> _selectedIntentionIds = <int>{};
  final Set<int> _selectedCoreValueIds = <int>{};
  final List<int> _selectedHobbyIds = <int>[];
  LocationItem? _selectedLocation;
  List<ProfessionModel> _selectedProfessions = <ProfessionModel>[];
  List<EducationModel> _selectedEducations = <EducationModel>[];

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    try {
      final List<ProfessionModel> professions = await ref.read(professionServiceProvider).searchProfessions('');
      final List<EducationModel> educations = await ref.read(educationServiceProvider).searchEducations('');
      if (mounted) {
        setState(() {
          _allProfessions = professions;
          _allEducations = educations;
        });
      }
    } catch (e) {
      debugPrint("Error loading resources: $e");
    }
  }

  void _showHeightPicker() {
    int initialValue = int.tryParse(_heightController.text) ?? 170;
    // Ensure initial value is within range [50, 300]
    if (initialValue < 50 || initialValue > 300) initialValue = 170;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A), // Dark background
      builder: (BuildContext context) {
        return SizedBox(
          height: 250,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    child: const Text('Done', style: TextStyle(color: Colors.white)),
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
                    setState(() {
                      _heightController.text = (index + 50).toString();
                    });
                  },
                  children: List<Widget>.generate(251, (int index) {
                    return Center(
                      child: Text(
                        '${index + 50} cm',
                        style: const TextStyle(color: Colors.white),
                      ),
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

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _heightController.dispose();
    _birthDateController.dispose();
    _birthTimeController.dispose();
    _bioController.dispose();
    _birthLocationController.dispose();
    _professionController.dispose();
    _educationController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('register.errors.birth_location_required'.tr())),
      );
      return;
    }
    if (_selectedCoreValueIds.isEmpty || _selectedHobbyIds.isEmpty || _selectedIntentionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('register.errors.fill_preferences'.tr())),
      );
      return;
    }

    int? heightInCm;
    if (_heightController.text.isNotEmpty) {
      final double? heightValue = double.tryParse(_heightController.text.replaceAll(',', '.'));
      if (heightValue != null) {
        // If user enters 1.75, treat as meters -> 175cm. If 175, treat as cm.
        heightInCm = (heightValue < 3.0) ? (heightValue * 100).round() : heightValue.round();
      }
    }

    final Map<String, dynamic> profileData = <String, dynamic>{
      // Include data from previous step (email, password)
      if (widget.data != null) ...widget.data!,
      
      "name": _nameController.text.trim(),
      "last_name": _lastNameController.text.trim(),
      "height": heightInCm,
      "birth_date": _birthDateController.text,
      "birth_time": _birthTimeController.text,
      "location_id": _selectedLocation!.id,
      "sex_id": _selectedGenderId,
      "orientation_id": _selectedOrientationId,
      "intention_ids": _selectedIntentionIds.toList(),
      "core_value_ids": _selectedCoreValueIds.toList(),
      "bio": _bioController.text.trim(),
      "hobby_ids": _selectedHobbyIds,
      "profession_ids": _selectedProfessions.map((ProfessionModel p) => p.id).toList(),
      "education_ids": _selectedEducations.map((EducationModel e) => e.id).toList(),
    };


    // Update the provider state immediately before navigation
    ref.read(registrationProvider.notifier).updateProfileData(profileData);
    
    if (mounted) context.go('/register-photos', extra: profileData);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Sex>> sexesAsync = ref.watch(sexesProvider);
    final AsyncValue<List<Orientations>> orientationsAsync = ref.watch(orientationsProvider);
    final AsyncValue<List<Hobby>> hobbiesAsync = ref.watch(hobbiesProvider);
    final coreValuesAsync = ref.watch(coreValuesProvider);
    final intentionsAsync = ref.watch(intentionsProvider);
    final bool isFinalizing = ref.watch(registrationProvider).step2Data['phone_number'] != null;

    return Container(
      decoration: const BoxDecoration(gradient: CosmicColors.deepSpaceGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => context.go('/register'),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          ),
          title: Text(
            isFinalizing ? 'register.finalize_registration'.tr() : 'register.step2_title'.tr(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: <Widget>[
              if (isFinalizing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Text(
                    'register.finalize_subtitle'.tr(),
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (String? value) => value == null || value.trim().isEmpty
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
                validator: (_) => null, // Last name is optional
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _heightController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Height (cm)', suffixIcon: Icon(Icons.height)),
                onTap: _showHeightPicker,
                validator: (String? value) => value == null || value.isEmpty ? 'Height is required' : null,
              ),
              const SizedBox(height: 24),

              // Birth date & time
              Text('register.natal_chart_title'.tr(),
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('register.natal_chart_subtitle'.tr(),
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _birthDateController,
                readOnly: true,
                decoration: InputDecoration(
                    labelText: 'register.dob_label'.tr(),
                    hintText: 'register.dob_hint'.tr()),
                onTap: () async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(2000),
                    firstDate: DateTime(1920),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null && mounted) {
                    _birthDateController.text =
                        "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                  }
                },
                validator: (String? value) =>
                    value == null || value.isEmpty ? 'register.errors.dob_required'.tr() : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _birthTimeController,
                readOnly: true,
                decoration: InputDecoration(
                    labelText: 'register.tob_label'.tr(),
                    hintText: 'register.tob_hint'.tr()),
                onTap: () async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null && mounted) {
                    _birthTimeController.text =
                        "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                  }
                },
                validator: (_) => null,
              ),
              const SizedBox(height: 16),
              // Birth Location
              TypeAheadField<LocationItem>(
                controller: _birthLocationController,

                suggestionsCallback: (String pattern) async {
                  return await ref.read(locationServiceProvider).searchLocations(pattern);
                },

                itemBuilder: (BuildContext context, LocationItem location) {
                  return ListTile(
                    title: Text(location.displayName,
                    style: const TextStyle(color: Colors.white),
                    ),
                  );
                },

                onSelected: (LocationItem location) {
                  _birthLocationController.text = location.displayName;
                  setState(() => _selectedLocation = location);
                },

                emptyBuilder: (BuildContext context) => const ListTile(
                  title: Text('No cities found'),
                ),

                loadingBuilder: (BuildContext context) => const Center(child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                )),
                builder: (BuildContext context, TextEditingController controller, FocusNode focusNode) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'register.birth_location_label'.tr(),
                      hintText: 'register.birth_location_hint'.tr(),
                    ),
                    validator: (String? value) => value == null || value.isEmpty
                        ? 'register.errors.birth_location_required'.tr()
                        : null,
                  );
                },
              ),

              // TypeAheadFormField<LocationItem>(
              //   textFieldConfiguration: TextFieldConfiguration(
              //     controller: _birthLocationController,
              //     decoration: InputDecoration(
              //       labelText: 'register.birth_location_label'.tr(),
              //       hintText: 'register.birth_location_hint'.tr(),
              //     ),
              //   ),
              //   suggestionsCallback: (pattern) async {
              //     if (pattern.isEmpty) return [];
              //     // Use ref.read as this is a one-off async call inside a callback
              //     return await ref.read(locationServiceProvider).searchLocations(pattern);
              //   },
              //   itemBuilder: (context, suggestion) {
              //     return ListTile(
              //       title: Text('${suggestion.name}, ${suggestion.parent?.name ?? ''}'),
              //     );
              //   },
              //   onSuggestionSelected: (suggestion) {
              //     _birthLocationController.text = '${suggestion.name}, ${suggestion.parent?.name ?? ''}';
              //     setState(() => _selectedLocation = suggestion);
              //   },
              //   validator: (value) => value == null || value.isEmpty ? 'register.errors.birth_location_required'.tr() : null,
             // ),
              const SizedBox(height: 24),

              // Gender
              Text('register.identity_title'.tr(),
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              sexesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object err, _) => Text('Error: $err'),
                data: (List<Sex> sexes) => DropdownButtonFormField<int>(
                  initialValue: _selectedGenderId,
                  decoration: InputDecoration(
                      labelText: 'register.gender_label'.tr(),
                      hintText: 'register.gender_hint'.tr()),
                  items: sexes
                      .map((Sex sex) => DropdownMenuItem<int>(
                            value: sex.id,
                            child: Text(sex.name.tr()),
                          ))
                      .toList(),
                  onChanged: (int? val) => setState(() => _selectedGenderId = val),
                  validator: (int? value) =>
                      value == null ? 'register.errors.gender_required'.tr() : null,
                ),
              ),
              const SizedBox(height: 16),

              // Orientation
              orientationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object err, _) => Text('Error: $err'),
                data: (List<Orientations> orientations) => DropdownButtonFormField<int>(
                  initialValue: _selectedOrientationId,
                  decoration: const InputDecoration(labelText: 'Orientation'),
                  items: orientations
                      .map((Orientations o) => DropdownMenuItem<int>(
                            value: o.id,
                            child: Text(o.translationKey.tr()),
                          ))
                      .toList(),
                  onChanged: (int? val) => setState(() => _selectedOrientationId = val),
                  validator: (int? value) =>
                      value == null ? 'Orientation is required' : null,
                ),
              ),
              const SizedBox(height: 16),

              // Intention
              Text('register.intention_label'.tr(),
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              intentionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object err, _) => Text('Error: $err'),
                data: (List<Intention> intentions) => Wrap(
                  spacing: 8.0,
                  children: intentions.map((Intention intention) {
                    final bool isSelected = _selectedIntentionIds.contains(intention.id);
                    return FilterChip(
                      label: Text(intention.translationKey.tr()),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _selectedIntentionIds.add(intention.id);
                          } else {
                            _selectedIntentionIds.remove(intention.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Core values
              Text('register.core_values_title'.tr(),
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('register.core_values_subtitle'.tr(),
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              coreValuesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object err, _) => Text('Error: $err'),
                data: (List<CoreValue> values) => Wrap(
                  spacing: 8.0,
                  children: values.map((CoreValue value) {
                    final bool isSelected = _selectedCoreValueIds.contains(value.id);
                    return FilterChip(
                      label: Text(value.translationKey.tr()),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            // Only add if the user is under the selection limit.
                            if (_selectedCoreValueIds.length < 5) {
                              _selectedCoreValueIds.add(value.id);
                            }
                          } else {
                            // Always allow deselection.
                            _selectedCoreValueIds.remove(value.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Hobbies
              const Text('Hobbies',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const Text('Select your hobbies', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              hobbiesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object err, _) => Text('Error: $err'),
                data: (List<Hobby> hobbies) => Wrap(
                  spacing: 8.0,
                  children: hobbies.map((Hobby hobby) {
                    final bool isSelected = _selectedHobbyIds.contains(hobby.id);
                    return FilterChip(
                      label: Text(hobby.name),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _selectedHobbyIds.add(hobby.id);
                          } else {
                            _selectedHobbyIds.remove(hobby.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Career & Education
              const Text('Career & Education',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),

              // Professions
              if (_selectedProfessions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Wrap(
                    spacing: 8,
                    children: _selectedProfessions.map((ProfessionModel p) => Chip(
                      label: Text(p.name),
                      onDeleted: () {
                        setState(() {
                          _selectedProfessions.remove(p);
                        });
                      },
                    )).toList(),
                  ),
                ),
              TypeAheadField<ProfessionModel>(
                controller: _professionController,
                suggestionsCallback: (String pattern) {
                  final Iterable<ProfessionModel> filtered = pattern.isEmpty
                      ? _allProfessions
                      : _allProfessions.where((ProfessionModel p) => p.name.toLowerCase().contains(pattern.toLowerCase()));
                  
                  // Exclude already selected items
                  return filtered.where((ProfessionModel p) => !_selectedProfessions.contains(p)).toList();
                },
                itemBuilder: (BuildContext context, ProfessionModel suggestion) {
                  return ListTile(title: Text(suggestion.name));
                },
                onSelected: (ProfessionModel suggestion) {
                  setState(() {
                    _selectedProfessions.add(suggestion);
                    _professionController.clear();
                  });
                },
                builder: (BuildContext context, TextEditingController controller, FocusNode focusNode) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Add Profession',
                      hintText: 'Type to search...',
                    ),
                  );
                },
                emptyBuilder: (BuildContext context) => const ListTile(title: Text('No professions found')),
              ),
              const SizedBox(height: 16),

              // Education
              if (_selectedEducations.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Wrap(
                    spacing: 8,
                    children: _selectedEducations.map((EducationModel e) => Chip(
                      label: Text(e.name),
                      onDeleted: () {
                        setState(() {
                          _selectedEducations.remove(e);
                        });
                      },
                    )).toList(),
                  ),
                ),
              TypeAheadField<EducationModel>(
                controller: _educationController,
                suggestionsCallback: (String pattern) {
                  final Iterable<EducationModel> filtered = pattern.isEmpty
                      ? _allEducations
                      : _allEducations.where((EducationModel e) => e.name.toLowerCase().contains(pattern.toLowerCase()));
                  
                  return filtered.where((EducationModel e) => !_selectedEducations.contains(e)).toList();
                },
                itemBuilder: (BuildContext context, EducationModel suggestion) {
                  return ListTile(title: Text(suggestion.name));
                },
                onSelected: (EducationModel suggestion) {
                  setState(() {
                    _selectedEducations.add(suggestion);
                    _educationController.clear();
                  });
                },
                builder: (BuildContext context, TextEditingController controller, FocusNode focusNode) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Add Education',
                      hintText: 'Type to search...',
                    ),
                  );
                },
                emptyBuilder: (BuildContext context) => const ListTile(title: Text('No education found')),
              ),
              const SizedBox(height: 24),

              // Bio
              TextFormField(
                controller: _bioController,
                decoration: InputDecoration(
                    labelText: 'register.bio_label'.tr(),
                    hintText: 'register.bio_hint'.tr()),
                maxLines: 3,
                maxLength: 280,
                validator: (String? value) => value == null || value.trim().isEmpty
                    ? 'register.errors.bio_required'.tr()
                    : null,
              ),
              const SizedBox(height: 24),

              // Submit button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: _submitForm,
                child: Text('register_main.continue_button'.tr()),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
