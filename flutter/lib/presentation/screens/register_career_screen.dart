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
  final List<ProfessionModel> _selectedProfessions = <ProfessionModel>[];
  final List<EducationModel> _selectedEducations = <EducationModel>[];
  List<ProfessionModel> _allProfessions = <ProfessionModel>[];
  List<EducationModel> _allEducations = <EducationModel>[];

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
    ref.read(registrationProvider.notifier).updateProfileData(<String, dynamic>{
      'profession_ids': _selectedProfessions.map((ProfessionModel p) => p.id).toList(),
      'education_ids': _selectedEducations.map((EducationModel e) => e.id).toList(),
    });
    context.push('/register-bio');
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'register.career_title'.tr(),
      progress: 9 / 10,
      onContinue: _onNext,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('register.career_subtitle'.tr(), style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            if (_selectedProfessions.isNotEmpty)
              Wrap(
                spacing: 8,
                children: _selectedProfessions.map((ProfessionModel p) {
                  final String label = p.translationKey.isNotEmpty && p.translationKey.tr() != p.translationKey
                      ? p.translationKey.tr() : p.name;
                  return Chip(
                    label: Text(label),
                    onDeleted: () => setState(() => _selectedProfessions.remove(p)),
                  );
                }).toList(),
              ),
            TypeAheadField<ProfessionModel>(
              controller: _professionController,
              suggestionsCallback: (String pattern) {
                return _allProfessions
                    .where((ProfessionModel p) => p.name.toLowerCase().contains(pattern.toLowerCase()) && !_selectedProfessions.contains(p))
                    .toList();
              },
              itemBuilder: (BuildContext context, ProfessionModel suggestion) {
                final String label = suggestion.translationKey.isNotEmpty && suggestion.translationKey.tr() != suggestion.translationKey
                    ? suggestion.translationKey.tr() : suggestion.name;
                return ListTile(title: Text(label));
              },
              onSelected: (ProfessionModel suggestion) => setState(() {
                _selectedProfessions.add(suggestion);
                _professionController.clear();
              }),
              builder: (BuildContext context, TextEditingController controller, FocusNode focusNode) => TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(labelText: 'register.profession_label'.tr()),
              ),
            ),
            const SizedBox(height: 24),
            if (_selectedEducations.isNotEmpty)
              Wrap(
                spacing: 8,
                children: _selectedEducations.map((EducationModel e) {
                  final String label = e.translationKey.isNotEmpty && e.translationKey.tr() != e.translationKey
                      ? e.translationKey.tr() : e.name;
                  return Chip(
                    label: Text(label),
                    onDeleted: () => setState(() => _selectedEducations.remove(e)),
                  );
                }).toList(),
              ),
            TypeAheadField<EducationModel>(
              controller: _educationController,
              suggestionsCallback: (String pattern) {
                return _allEducations
                    .where((EducationModel e) => e.name.toLowerCase().contains(pattern.toLowerCase()) && !_selectedEducations.contains(e))
                    .toList();
              },
              itemBuilder: (BuildContext context, EducationModel suggestion) {
                final String label = suggestion.translationKey.isNotEmpty && suggestion.translationKey.tr() != suggestion.translationKey
                    ? suggestion.translationKey.tr() : suggestion.name;
                return ListTile(title: Text(label));
              },
              onSelected: (EducationModel suggestion) => setState(() {
                _selectedEducations.add(suggestion);
                _educationController.clear();
              }),
              builder: (BuildContext context, TextEditingController controller, FocusNode focusNode) => TextFormField(
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