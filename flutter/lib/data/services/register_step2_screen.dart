import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/domain/entities/profile_options.dart';
import 'package:syno_app/data/services/user_service.dart'; 
import 'package:dio/dio.dart'; 
import 'package:easy_localization/easy_localization.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart'; 

// Providers to fetch the dynamic options
final FutureProvider<List<Intention>> intentionsProvider = FutureProvider<List<Intention>>((Ref ref) async {
  // Replace with your actual API call logic
  final Response response = await Dio().get('http://localhost:8000/api/intentions');
  return (response.data as List).map((i) => Intention.fromJson(i)).toList();
});

final FutureProvider<List<CoreValue>> coreValuesProvider = FutureProvider<List<CoreValue>>((Ref ref) async {
  // Replace with your actual API call logic
  final Response response = await Dio().get('http://localhost:8000/api/core-values');
  return (response.data as List).map((cv) => CoreValue.fromJson(cv)).toList();
});

class RegisterStep2Screen extends ConsumerStatefulWidget {
  const RegisterStep2Screen({super.key});

  @override
  _RegisterStep2ScreenState createState() => _RegisterStep2ScreenState();
}

class _RegisterStep2ScreenState extends ConsumerState<RegisterStep2Screen> {
  final Set<int> _selectedIntentionIds = <int>{};
  final Set<int> _selectedCoreValueIds = <int>{};

  // ... other form controllers for bio, etc.

  void _saveProfile() {
    // Assuming you have a user service instance from a provider
    final UserService userService = ref.read(userServiceProvider);

    final Map<String, List<int>> profileData = <String, List<int>>{
      // ... other profile data like bio, gender, etc.
      'intention_ids': _selectedIntentionIds.toList(),
      'core_value_ids': _selectedCoreValueIds.toList(),
    };

    // The user service will now send these IDs to the backend
    userService.createProfileWithPhotos(profileData, <String>[]); // Pass photo paths if any
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Intention>> intentionsAsync = ref.watch(intentionsProvider);
    final AsyncValue<List<CoreValue>> coreValuesAsync = ref.watch(coreValuesProvider);

    return Scaffold(
      appBar: AppBar(title: Text('register.step2_title'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ... other form fields for DOB, location, etc.

            Text('register.intention_label'.tr(), style: Theme.of(context).textTheme.titleLarge),
            intentionsAsync.when(
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
              loading: () => const CircularProgressIndicator(),
              error: (Object e, StackTrace st) => Text('Failed to load intentions: $e'),
            ),

            const SizedBox(height: 24),

            Text('register.core_values_title'.tr(), style: Theme.of(context).textTheme.titleLarge),
            coreValuesAsync.when(
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
              error: (Object e, StackTrace st) => Text('Failed to load core values: $e'),
            ),
            
            // ... Bio field and Finish button that calls _saveProfile()
          ],
        ),
      ),
    );
  }
}