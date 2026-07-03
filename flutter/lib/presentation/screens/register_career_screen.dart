import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:syno_app/data/services/profession_service.dart';
import 'package:syno_app/data/services/education_service.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/widgets/onboarding_scaffold.dart';

class RegisterCareerScreen extends ConsumerStatefulWidget {
  const RegisterCareerScreen({super.key});

  @override
  ConsumerState<RegisterCareerScreen> createState() => _RegisterCareerScreenState();
}

class _RegisterCareerScreenState extends ConsumerState<RegisterCareerScreen> {
  final TextEditingController _professionController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final List<ProfessionModel> _selectedProfessions = [];
  final List<EducationModel> _selectedEducations = [];
  List<ProfessionModel> _allProfessions = [];
  List<EducationModel> _allEducations = [];

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    final professions = await ref.read(professionServiceProvider).searchProfessions('');
    final educations = await ref.read(educationServiceProvider).searchEducations('');
    setState(() {
      _allProfessions = professions;
      _allEducations = educations;
    });
  }

  void _onNext() {
    ref.read(registrationProvider.notifier).updateProfileData({
      'profession_ids': _selectedProfessions.map((p) => p.id).toList(),
      'education_ids': _selectedEducations.map((e) => e.id).toList(),
    });
    context.push('/register-bio');
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'register.career_title'.tr(),
      progress: 8 / 9,
      onContinue: _onNext,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('register.career_subtitle'.tr(), style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            if (_selectedProfessions.isNotEmpty)
              Wrap(
                spacing: 8,
                children: _selectedProfessions.map((p) => Chip(
                  label: Text(p.name),
                  onDeleted: () => setState(() => _selectedProfessions.remove(p)),
                )).toList(),
              ),
            TypeAheadField<ProfessionModel>(
              controller: _professionController,
              suggestionsCallback: (pattern) {
                return _allProfessions
                    .where((p) => p.name.toLowerCase().contains(pattern.toLowerCase()) && !_selectedProfessions.contains(p))
                    .toList();
              },
              itemBuilder: (context, suggestion) => ListTile(title: Text(suggestion.name)),
              onSelected: (suggestion) => setState(() {
                _selectedProfessions.add(suggestion);
                _professionController.clear();
              }),
              builder: (context, controller, focusNode) => TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(labelText: 'register.profession_label'.tr()),
              ),
            ),
            const SizedBox(height: 24),
            if (_selectedEducations.isNotEmpty)
              Wrap(
                spacing: 8,
                children: _selectedEducations.map((e) => Chip(
                  label: Text(e.name),
                  onDeleted: () => setState(() => _selectedEducations.remove(e)),
                )).toList(),
              ),
            TypeAheadField<EducationModel>(
              controller: _educationController,
              suggestionsCallback: (pattern) {
                return _allEducations
                    .where((e) => e.name.toLowerCase().contains(pattern.toLowerCase()) && !_selectedEducations.contains(e))
                    .toList();
              },
              itemBuilder: (context, suggestion) => ListTile(title: Text(suggestion.name)),
              onSelected: (suggestion) => setState(() {
                _selectedEducations.add(suggestion);
                _educationController.clear();
              }),
              builder: (context, controller, focusNode) => TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(labelText: 'register.education_label'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}