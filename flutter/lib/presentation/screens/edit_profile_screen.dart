import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/user_provider.dart' hide userServiceProvider;
import 'package:syno_app/presentation/widgets/app_dialogs.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  bool _isUploading = false;
  String? _token;

  late TextEditingController _nameController;
  late TextEditingController _lastNameController;
  late TextEditingController _bioController;
  bool _initialDataLoaded = false;

  DateTime? _birthDate;
  TimeOfDay? _birthTime;

  List<dynamic> _sexes = [];
  List<dynamic> _orientations = [];
  List<dynamic> _hobbies = [];
  List<dynamic> _educations = [];
  List<dynamic> _professions = [];
  List<dynamic> _coreValues = [];
  List<dynamic> _intentions = [];

  String? _selectedSexId;
  String? _selectedOrientationId;
  Set<int> _selectedHobbyIds = {};
  Set<int> _selectedEducationIds = {};
  Set<int> _selectedProfessionIds = {};
  Set<String> _selectedCoreValues = {};
  Set<String> _selectedIntentionKeys = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _lastNameController = TextEditingController();
    _bioController = TextEditingController();
    _loadToken();
    _fetchStaticData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _token = prefs.getString('auth_token'));
  }

  Future<void> _fetchStaticData() async {
    final backendUrl = ref.read(backendUrlProvider);
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$backendUrl/api/sexes/')),
        http.get(Uri.parse('$backendUrl/api/orientations/')),
        http.get(Uri.parse('$backendUrl/api/hobbies/')),
        http.get(Uri.parse('$backendUrl/api/educations/')),
        http.get(Uri.parse('$backendUrl/api/professions/')),
        http.get(Uri.parse('$backendUrl/api/core-values/')),
        http.get(Uri.parse('$backendUrl/api/intentions/')),
      ]);

      if (mounted) {
        setState(() {
          if (responses[0].statusCode == 200) _sexes = jsonDecode(responses[0].body);
          if (responses[1].statusCode == 200) _orientations = jsonDecode(responses[1].body);
          if (responses[2].statusCode == 200) _hobbies = jsonDecode(responses[2].body);
          if (responses[3].statusCode == 200) _educations = jsonDecode(responses[3].body);
          if (responses[4].statusCode == 200) _professions = jsonDecode(responses[4].body);
          if (responses[5].statusCode == 200) _coreValues = jsonDecode(responses[5].body);
          if (responses[6].statusCode == 200) _intentions = jsonDecode(responses[6].body);
        });
      }
    } catch (e) {
      debugPrint('Error fetching static data: $e');
    }
  }

  Future<void> _pickAndUploadPhoto({required bool isPrimary}) async {
    if (!isPrimary) {
      final user = ref.read(currentUserProvider).value;
      final additionalCount = user?.photos.where((p) => p.isPrimary != true).length ?? 0;
      if (user != null && additionalCount >= 6) {
        if (mounted) {
          AppDialogs.showErrorDialog(
              context, "Photo Limit Reached", "You can upload a maximum of 6 additional photos.");
        }
        return;
      }
    }

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;
      if (!mounted) return;

      setState(() => _isUploading = true);

      await ref.read(currentUserProvider.notifier).createProfileWithPhotos({}, [image.path], firstIsPrimary: isPrimary);

      if (!mounted) return;
      await AppDialogs.showSuccessDialog(
        context, "Success", "Profile photo updated successfully.",
        onDismiss: () {});
    } catch (e) {
      if (mounted) AppDialogs.showErrorDialog(context, "Error", "Error: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _confirmDeletePhoto(int photoId) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: CosmicColors.grey800,
          title: const Text("Delete Photo", style: TextStyle(color: Colors.white)),
          content: const Text("Are you sure you want to delete this photo?",
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    setState(() => _isUploading = true);
    try {
      await ref.read(currentUserProvider.notifier).deletePhoto(photoId);
      if (!mounted) return;
      ref.invalidate(currentUserProvider);
      
      if (mounted) {
        await AppDialogs.showSuccessDialog(
            context, "Success", "Photo deleted successfully",
            onDismiss: () {});
      }
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showErrorDialog(context, "Deletion Failed", e.toString());
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _birthDate && mounted) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _birthTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _birthTime && mounted) {
      setState(() => _birthTime = picked);
    }
  }

  void _initializeControllers(User user) {
    if (_initialDataLoaded) return;

    _nameController.text = user.name ?? '';
    _lastNameController.text = user.lastName ?? '';
    _bioController.text = user.bio ?? '';
    _birthDate = user.birthDate;
    if (user.intentions != null) {
      final dynamic rawIntentions = user.intentions;
      if (rawIntentions is Iterable) {
        _selectedIntentionKeys = rawIntentions.map<String>((i) {
          try {
            if (i is Map) {
              return (i['key'] ?? i['translation_key'] ?? i.toString()) as String;
            }
            final dynamic item = i;
            return (item.key ?? item.translationKey ?? item.toString()).toString();
          } catch (_) {
            return i.toString();
          }
        }).toSet();
      } else {
        _selectedIntentionKeys = {rawIntentions.toString()};
      }
    }

    _selectedSexId = user.sex?.id.toString();
    _selectedOrientationId = user.orientation?.id.toString();
    _selectedHobbyIds = user.hobbies.map((h) => h.id).toSet();
    _selectedEducationIds = user.educations.map((e) => e.id).toSet();
    _selectedProfessionIds = user.professions.map((p) => p.id).toSet();
    _selectedCoreValues = user.coreValues.map((t) => t.key).toSet();

    if (user.birthTime != null) {
      try {
        final parts = user.birthTime!.split(':');
        _birthTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (e) {
        debugPrint("Time parsing error: $e");
      }
    }
    _initialDataLoaded = true;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isUploading = true);

    try {
      // Map selected intention keys to IDs
      final intentionIds = _intentions
          .where((i) => _selectedIntentionKeys.contains(i['key']))
          .map((i) => i['id'] as int)
          .toList();

      // 1. Prepare profile data
      final Map<String, dynamic> data = {
        'name': _nameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'birth_date': _birthDate?.toIso8601String().split('T')[0],
        'sex_id': int.tryParse(_selectedSexId ?? ''),
        'orientation_id': int.tryParse(_selectedOrientationId ?? ''),
        'hobby_ids': _selectedHobbyIds.toList(),
        'education_ids': _selectedEducationIds.toList(),
        'profession_ids': _selectedProfessionIds.toList(),
        'core_value_ids': _coreValues
            .where((v) => _selectedCoreValues.contains(v['key'] as String))
            .map((v) => v['id'] as int)
            .toList(),
      };

      if (intentionIds.isNotEmpty) {
        data['intention_ids'] = intentionIds;
      }

      if (_birthTime != null) {
        data['birth_time'] =
            "${_birthTime!.hour.toString().padLeft(2, '0')}:${_birthTime!.minute.toString().padLeft(2, '0')}";
      }
      data.removeWhere((key, value) => value == null);

      // 2. Update the profile data. The service handles photos separately.
      await ref.read(currentUserProvider.notifier).createProfileWithPhotos(data, []);

      // 3. Invalidate the provider to force a refetch of the complete, updated user profile
      ref.invalidate(currentUserProvider);

      if (mounted) {
        await AppDialogs.showSuccessDialog(
          context, 
          "profile.updated".tr(), 
          "profile.changes_saved".tr(), 
          onDismiss: () => Navigator.pop(context)
        );
      }
    } catch (e) {
      if (mounted) AppDialogs.showErrorDialog(context, "Update Failed", e.toString());
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  InputDecoration _getInputDecoration(String label, IconData icon, Color textColor) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: textColor.withOpacity(0.7)),
      labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textColor.withOpacity(0.3))),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final theme = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('profile.edit_profile'.tr(),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: theme.primaryTextColor)),
        iconTheme: IconThemeData(color: theme.primaryTextColor),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isUploading
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryTextColor))
                : Icon(Icons.check, color: theme.primaryTextColor),
            onPressed: _isUploading ? null : _saveProfile,
          )
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
          data: (user) {
            if (user == null) return const Center(child: Text("User not found"));
            _initializeControllers(user);

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
                children: [
                  // --- PROFILE AVATAR ---
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 70,
                          backgroundColor: Colors.white10,
                          backgroundImage: (user.photos.any((p) => p.isPrimary) && _token != null)
                              ? NetworkImage(
                                  '${ref.read(backendUrlProvider)}/api/photos/${user.photos.firstWhere((p) => p.isPrimary).id}',
                                  headers: {'Authorization': 'Bearer $_token'})
                              : null,
                          child: !user.photos.any((p) => p.isPrimary)
                              ? Icon(Icons.person, size: 50, color: theme.primaryTextColor)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: FloatingActionButton.small(
                              backgroundColor: Colors.blueAccent,
                            onPressed: () => _pickAndUploadPhoto(isPrimary: true),
                            child: const Icon(Icons.camera_alt, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- GALLERY ---
                  Text("Gallery", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.primaryTextColor)),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: user.photos.where((p) => !p.isPrimary).length + 
                        (user.photos.where((p) => !p.isPrimary).length < 6 ? 1 : 0),
                    itemBuilder: (context, index) {
                      final additionalPhotos = user.photos.where((p) => !p.isPrimary).toList();
                      if (index == additionalPhotos.length) {
                        return GestureDetector(
                          onTap: () => _pickAndUploadPhoto(isPrimary: false),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: theme.primaryTextColor.withOpacity(0.3)),
                            ),
                            child: Icon(Icons.add_a_photo, color: theme.primaryTextColor.withOpacity(0.5)),
                          ),
                        );
                      }
                      final photo = additionalPhotos[index];
                      return Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: (_token != null) ? DecorationImage(
                                image: NetworkImage(
                                    '${ref.read(backendUrlProvider)}/api/photos/${photo.id}',
                                    headers: {'Authorization': 'Bearer $_token'}),
                                fit: BoxFit.cover,
                              ) : null,
                            ),
                          ),
                          Positioned(
                            top: 5,
                            right: 5,
                            child: GestureDetector(
                              onTap: () => _confirmDeletePhoto(photo.id),
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  Divider(color: theme.primaryTextColor.withOpacity(0.2)),
                  const SizedBox(height: 20),

                  // --- TEXT FIELDS ---
                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(color: theme.primaryTextColor),
                    decoration: _getInputDecoration("First Name", Icons.person_outline, theme.primaryTextColor),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _lastNameController,
                    style: TextStyle(color: theme.primaryTextColor),
                    decoration: _getInputDecoration("Last Name", Icons.person_outline, theme.primaryTextColor),
                    validator: (v) => null, // Last name is optional
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _bioController,
                    maxLines: 4,
                    style: TextStyle(color: theme.primaryTextColor),
                    decoration: _getInputDecoration("Bio", Icons.edit_note, theme.primaryTextColor),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Bio is required' : null,
                  ),
                  const SizedBox(height: 20),

                  // --- DATE & TIME ---
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context),
                          child: InputDecorator(
                            decoration: _getInputDecoration("Birth Date", Icons.calendar_today, theme.primaryTextColor),
                            child: Text(
                              _birthDate != null ? DateFormat('yyyy-MM-dd').format(_birthDate!) : 'Select Date',
                              style: TextStyle(color: theme.primaryTextColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context),
                          child: InputDecorator(
                            decoration: _getInputDecoration("Birth Time", Icons.access_time, theme.primaryTextColor),
                            child: Text(
                              _birthTime != null ? _birthTime!.format(context) : 'Select Time',
                              style: TextStyle(color: theme.primaryTextColor),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- INTENTIONS ---
                  Text("profile.intention".tr(), style: TextStyle(fontSize: 16, color: theme.primaryTextColor.withOpacity(0.7))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: _intentions.map((intention) {
                      final key = intention['key'].toString();
                      final translationKey = intention['translation_key'].toString();
                      return FilterChip(
                        label: Text(translationKey.tr()),
                        selected: _selectedIntentionKeys.contains(key),
                        onSelected: (selected) => setState(() {
                          if (selected) _selectedIntentionKeys.add(key);
                          else _selectedIntentionKeys.remove(key);
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _sexes.any((s) => s['id'].toString() == _selectedSexId) ? _selectedSexId : null,
                          style: TextStyle(color: theme.primaryTextColor),
                          dropdownColor: Theme.of(context).cardColor,
                          decoration: _getInputDecoration("Sex", Icons.transgender, theme.primaryTextColor),
                          items: _sexes.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name'].toString()))).toList(),
                          onChanged: (val) => setState(() => _selectedSexId = val),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _orientations.any((o) => o['id'].toString() == _selectedOrientationId) ? _selectedOrientationId : null,
                          style: TextStyle(color: theme.primaryTextColor),
                          dropdownColor: Theme.of(context).cardColor,
                          decoration: _getInputDecoration("Orientation", Icons.explore_outlined, theme.primaryTextColor),
                          items: _orientations.map((o) => DropdownMenuItem(value: o['id'].toString(), child: Text(o['name'].toString()))).toList(),
                          onChanged: (val) => setState(() => _selectedOrientationId = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // --- CORE VALUES ---
                  Text("Core Values", style: TextStyle(fontSize: 16, color: theme.primaryTextColor.withOpacity(0.7))),
                  Text("Select up to 5", style: TextStyle(fontSize: 12, color: theme.primaryTextColor.withOpacity(0.5))),
                  const SizedBox(height: 8),
                  Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _coreValues.map((value) {
                    // 1. Safe extraction (using 'as String?' allows nulls without crashing)
                    final String? rawKey = value['key'] as String?;
                    final String? rawTranslationKey = value['translation_key'] as String?;

                    // 2. Decide which key to use for translation lookup
                    final String lookupPath = rawTranslationKey ?? rawKey ?? 'unknown';

                    // 3. Determine selection state using the unique key
                    final isSelected = _selectedCoreValues.contains(rawKey);

                    return FilterChip(
                      // 4. Translate the path once here
                      label: Text(lookupPath.tr()), 
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            if (_selectedCoreValues.length < 5 && rawKey != null) {
                              _selectedCoreValues.add(rawKey);
                            }
                          } else {
                            _selectedCoreValues.remove(rawKey);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                  const SizedBox(height: 20),

                  // --- HOBBIES ---
                  Text("Hobbies", style: TextStyle(fontSize: 16, color: theme.primaryTextColor.withOpacity(0.7))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: _hobbies.map((hobby) => FilterChip(
                      label: Text(hobby['name'].toString()),
                      selected: _selectedHobbyIds.contains(hobby['id']),
                      onSelected: (selected) => setState(() {
                        if (selected) _selectedHobbyIds.add(hobby['id']);
                        else _selectedHobbyIds.remove(hobby['id']);
                      }),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),

                  // --- EDUCATION ---
                  Text("Education", style: TextStyle(fontSize: 16, color: theme.primaryTextColor.withOpacity(0.7))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: _educations.map((edu) => FilterChip(
                      label: Text(edu['name'].toString()),
                      selected: _selectedEducationIds.contains(edu['id']),
                      onSelected: (selected) => setState(() {
                        if (selected) _selectedEducationIds.add(edu['id']);
                        else _selectedEducationIds.remove(edu['id']);
                      }),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),

                  // --- PROFESSION ---
                  Text("Profession", style: TextStyle(fontSize: 16, color: theme.primaryTextColor.withOpacity(0.7))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: _professions.map((prof) => FilterChip(
                      label: Text(prof['name'].toString()),
                      selected: _selectedProfessionIds.contains(prof['id']),
                      onSelected: (selected) => setState(() {
                        if (selected) _selectedProfessionIds.add(prof['id']);
                        else _selectedProfessionIds.remove(prof['id']);
                      }),
                    )).toList(),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}               