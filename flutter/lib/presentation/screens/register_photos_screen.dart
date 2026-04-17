import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/loading_provider.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/providers/user_provider.dart' hide userServiceProvider;
import 'package:syno_app/presentation/screens/theme.dart';
import 'package:syno_app/presentation/widgets/app_dialogs.dart';

class RegisterPhotosScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? profileData;

  const RegisterPhotosScreen({super.key, this.profileData});

  @override
  ConsumerState<RegisterPhotosScreen> createState() => _RegisterPhotosScreenState();
}

class _RegisterPhotosScreenState extends ConsumerState<RegisterPhotosScreen> {
  final int _maxPhotos = 6;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // The provider should have been updated by the previous screen (RegisterScreen2).
    // This is a safety check for cases where this screen is loaded directly without
    // going through the flow (e.g., web refresh, hot restart).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final regState = ref.read(registrationProvider);
      if (regState.profileData.isInitial) {
        // If profile data is missing, the user shouldn't be here.
        // Redirect them back to the start of the profile data form.
        if (mounted) context.go('/register-step2');
      }
    });
  }

  Future<void> _pickPhotos() async {
    final photos = ref.read(registrationProvider).photos;
    if (photos.length >= _maxPhotos) {
      if (mounted) AppDialogs.showErrorDialog(context, "register.limit_reached".tr(), "register.limit_message".tr(namedArgs: {'max': '$_maxPhotos'}));
      return;
    }

    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty && mounted) {
        int remainingSlots = _maxPhotos - photos.length;
        ref.read(registrationProvider.notifier).addPhotos(images.take(remainingSlots).toList());
      }
    } catch (e) {
      debugPrint("Photo Picker Error: $e");
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    // Index 0 is reserved for Primary, so we offset the gallery reorder by +1
    ref.read(registrationProvider.notifier).reorderPhotos(oldIndex + 1, newIndex + 1);
  }

  Future<void> _completeRegistration() async {
    final regState = ref.read(registrationProvider);

    // 1. Get profile data from the provider, which is now the single source of truth.
    // The initState of this widget updates the provider with widget.profileData.
    final profile = regState.profileData;

    final Map<String, dynamic> finalPayload = profile.toMap();
   

    // 2. Perform a strong validation check for the essential 'name' field.
    if (profile.isInitial || profile.name == null || profile.name!.trim().isEmpty) {
      if (mounted) AppDialogs.showErrorDialog(context, "register.missing_data".tr(), "register.missing_name_error".tr());
      return; 
    }

    if (regState.email.isEmpty || regState.password.isEmpty) {
      if (mounted) AppDialogs.showErrorDialog(context, "register.missing_data".tr(), "register.missing_creds_error".tr());
      return;
    }

    ref.read(loadingStateProvider.notifier).show();

    try {
  
      await ref.read(authProvider.notifier).registerCompleteUser(regState);
      
      if (!mounted) return;

      final freshUser = await ref.read(userServiceProvider).fetchUser();

      if (!mounted) return;

      // Hide loading indicator and reset registration state
      ref.read(registrationProvider.notifier).reset();
      ref.read(loadingStateProvider.notifier).hide();

      if (freshUser != null) {
        ref.read(currentUserProvider.notifier).setUser(freshUser);
      } else {
        // This case should not happen if registration was successful and the
        // backend endpoint is working correctly.
        throw Exception("Failed to fetch user profile after registration.");
      }

      // Show success and navigate
      if (mounted) {
        AppDialogs.showSuccessDialog(
          context,
          "register.welcome_title".tr(),
          "register.welcome_message".tr(),
          onDismiss: () => context.go('/theme-selection'),
        );
      }
    } catch (e) {
      if (mounted) {
        ref.read(loadingStateProvider.notifier).hide();
        AppDialogs.showErrorDialog(context, "register.failed_title".tr(), e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(registrationProvider).photos;
    final bool canComplete = photos.length >= 2;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/register-step2'),
        ),
        title: Text('register.photos_title'.tr()),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: CosmicColors.deepSpaceGradient),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 100.0, 24.0, 24.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Text('register.photos_subtitle'.tr(), style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 30),
              
              _buildPrimarySlot(photos),
              
              const SizedBox(height: 30),
              Align(
                alignment: Alignment.centerLeft,
                child: Text("register.additional_photos".tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              ),
              const SizedBox(height: 12),
              
              // Fixed height container for horizontal gallery
              SizedBox(
                height: 120,
                child: photos.length <= 1
                    ? _buildEmptyGalleryPlaceholder()
                    : ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length - 1,
                        onReorder: _onReorder,
                        itemBuilder: (context, index) {
                          final actualIdx = index + 1;
                          return _buildGalleryItem(photos[actualIdx], actualIdx);
                        },
                      ),
              ),
              
              const Spacer(),
              
              if (photos.length < _maxPhotos)
                TextButton.icon(
                  onPressed: _pickPhotos,
                  icon: const Icon(Icons.add_a_photo, color: CosmicColors.cosmicPink),
                  label: Text("register.add_more".tr(namedArgs: {'current': '${photos.length}', 'max': '$_maxPhotos'}), style: const TextStyle(color: CosmicColors.cosmicPink)),
                ),
                
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canComplete ? _completeRegistration : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: canComplete ? CosmicColors.cosmicPink : Colors.grey.shade800,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(canComplete ? 'register.complete_registration'.tr() : 'register.min_photos_required'.tr()),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimarySlot(List<XFile> photos) {
    final bool hasPhoto = photos.isNotEmpty;
    return GestureDetector(
      onTap: hasPhoto ? null : _pickPhotos,
      child: Container(
        width: 180,
        height: 240,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasPhoto ? CosmicColors.cosmicPink : Colors.white10, 
            width: 2,
          ),
          image: hasPhoto 
              ? DecorationImage(image: FileImage(File(photos[0].path)), fit: BoxFit.cover) 
              : null,
        ),
        child: Stack(
          children: [
            if (!hasPhoto)
              const Center(child: Icon(Icons.star_border, size: 40, color: Colors.white24)),
            if (hasPhoto) ...[
              Positioned(
                top: 10,
                left: 10,
                child: _badge("register.primary_badge".tr()),
              ),
              Positioned(
                top: -5,
                right: -5,
                child: IconButton(
                  icon: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, size: 16, color: Colors.white)),
                  onPressed: () => ref.read(registrationProvider.notifier).removePhotoAt(0),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryItem(XFile photo, int index) {
    return Container(
      key: ValueKey(photo.path),
      width: 90,
      height: 120,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(image: FileImage(File(photo.path)), fit: BoxFit.cover),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 2,
            top: 2,
            child: GestureDetector(
              onTap: () => ref.read(registrationProvider.notifier).removePhotoAt(index),
              child: const CircleAvatar(radius: 10, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 12, color: Colors.white)),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _badge('register.photo_index'.tr(args: [index.toString()])),
            ),
          )
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(5)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyGalleryPlaceholder() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10, style: BorderStyle.solid),
      ),
      child: Center(
        child: Text(
          'register.drag_placeholder'.tr(),
          style: const TextStyle(color: Colors.white24),
        ),
      ),
    );
  }
}