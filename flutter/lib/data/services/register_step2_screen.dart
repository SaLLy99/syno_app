import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/domain/entities/profile_options.dart';
import 'package:syno_app/data/services/user_service.dart'; 
import 'package:dio/dio.dart'; 
import 'package:easy_localization/easy_localization.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart'; 

// Providers to fetch the dynamic options
final intentionsProvider = FutureProvider<List<Intention>>((ref) async {
  // Replace with your actual API call logic
  final response = await Dio().get('http://localhost:8000/api/intentions');
  return (response.data as List).map((i) => Intention.fromJson(i)).toList();
});

final coreValuesProvider = FutureProvider<List<CoreValue>>((ref) async {
  // Replace with your actual API call logic
  final response = await Dio().get('http://localhost:8000/api/core-values');
  return (response.data as List).map((cv) => CoreValue.fromJson(cv)).toList();
});

class RegisterStep2Screen extends ConsumerStatefulWidget {
  const RegisterStep2Screen({Key? key}) : super(key: key);

  @override
  _RegisterStep2ScreenState createState() => _RegisterStep2ScreenState();
}

class _RegisterStep2ScreenState extends ConsumerState<RegisterStep2Screen> {
  final Set<int> _selectedIntentionIds = {};
  final Set<int> _selectedCoreValueIds = {};

  // ... other form controllers for bio, etc.

  void _saveProfile() {
    // Assuming you have a user service instance from a provider
    final userService = ref.read(userServiceProvider);

    final profileData = {
      // ... other profile data like bio, gender, etc.
      'intention_ids': _selectedIntentionIds.toList(),
      'core_value_ids': _selectedCoreValueIds.toList(),
    };

    // The user service will now send these IDs to the backend
    userService.createProfileWithPhotos(profileData, []); // Pass photo paths if any
  }

  @override
  Widget build(BuildContext context) {
    final intentionsAsync = ref.watch(intentionsProvider);
    final coreValuesAsync = ref.watch(coreValuesProvider);

    return Scaffold(
      appBar: AppBar(title: Text('register.step2_title'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... other form fields for DOB, location, etc.

            Text('register.intention_label'.tr(), style: Theme.of(context).textTheme.titleLarge),
            intentionsAsync.when(
              data: (intentions) => Wrap(
                spacing: 8.0,
                children: intentions.map((intention) {
                  final isSelected = _selectedIntentionIds.contains(intention.id);
                  return FilterChip(
                    label: Text(intention.translationKey.tr()),
                    selected: isSelected,
                    onSelected: (selected) {
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
              loading: () => const CircularProgressIndicator(),
              error: (e, st) => Text('Failed to load intentions: $e'),
            ),

            const SizedBox(height: 24),

            Text('register.core_values_title'.tr(), style: Theme.of(context).textTheme.titleLarge),
            coreValuesAsync.when(
              data: (values) => Wrap(
                spacing: 8.0,
                children: values.map((value) {
                  final isSelected = _selectedCoreValueIds.contains(value.id);
                  return FilterChip(
                    label: Text(value.translationKey.tr()),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCoreValueIds.add(value.id);
                        } else {
                          _selectedCoreValueIds.remove(value.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, st) => Text('Failed to load core values: $e'),
            ),
            
            // ... Bio field and Finish button that calls _saveProfile()
          ],
        ),
      ),
    );
  }
}