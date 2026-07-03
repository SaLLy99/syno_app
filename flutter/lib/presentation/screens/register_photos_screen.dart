import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/loading_provider.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/providers/user_provider.dart'
    hide userServiceProvider;
import 'package:syno_app/presentation/screens/theme.dart';
import 'package:syno_app/presentation/widgets/app_dialogs.dart';
import 'package:syno_app/presentation/widgets/onboarding_scaffold.dart';

class RegisterPhotosScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? profileData;

  const RegisterPhotosScreen({super.key, this.profileData});

  @override
  ConsumerState<RegisterPhotosScreen> createState() =>
      _RegisterPhotosScreenState();
}

class _RegisterPhotosScreenState extends ConsumerState<RegisterPhotosScreen> {
  final int _maxPhotos = 6;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // going through the flow.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final regState = ref.read(registrationProvider);
      if (regState.profileData.name == null) {
        // If name is missing, the user shouldn't be here. Redirect them back to the name step.
        if (mounted) context.go('/register-name');
      }
    });
  }

  Future<void> _pickPhotos() async {
    final photos = ref.read(registrationProvider).photos;
    if (photos.length >= _maxPhotos) {
      if (mounted)
        AppDialogs.showErrorDialog(context, "register.limit_reached".tr(),
            "register.limit_message".tr(namedArgs: {'max': '$_maxPhotos'}));
      return;
    }

    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty && mounted) {
        int remainingSlots = _maxPhotos - photos.length;
        ref
            .read(registrationProvider.notifier)
            .addPhotos(images.take(remainingSlots).toList());
      }
    } catch (e) {
      debugPrint("Photo Picker Error: $e");
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    // Index 0 is reserved for Primary, so we offset the gallery reorder by +1
    ref
        .read(registrationProvider.notifier)
        .reorderPhotos(oldIndex + 1, newIndex + 1);
  }

  void _onNext() {
    context.push('/register-identity');
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(registrationProvider).photos;
    final bool canComplete = photos.length >= 2;

    return OnboardingScaffold(
      title: 'register.photos_title'.tr(),
      progress: 2 / 9,
      canContinue: canComplete,
      onContinue: _onNext,
      continueLabel: canComplete
          ? 'register.continue'.tr()
          : 'register.min_photos_required'.tr(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
        child: Column(
          children: [
            Text('register.photos_subtitle'.tr(),
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 30),

            _buildPrimarySlot(photos),

            const SizedBox(height: 30),
            Align(
              alignment: Alignment.centerLeft,
              child: Text("register.additional_photos".tr(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white)),
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

            const SizedBox(height: 32),

            if (photos.length < _maxPhotos)
              TextButton.icon(
                onPressed: _pickPhotos,
                icon: const Icon(Icons.add_a_photo,
                    color: CosmicColors.cosmicPink),
                label: Text(
                    "register.add_more".tr(namedArgs: {
                      'current': '${photos.length}',
                      'max': '$_maxPhotos'
                    }),
                    style: const TextStyle(color: CosmicColors.cosmicPink)),
              ),

            if (!canComplete && photos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('register.min_photos_required'.tr(),
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimarySlot(List<XFile> photos) {
    final bool hasPhoto = photos.isNotEmpty;
    return GestureDetector(
      onTap: hasPhoto ? null : _pickPhotos,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutBack,
        child: Container(
          key: ValueKey<bool>(hasPhoto),
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
                ? DecorationImage(
                    image: FileImage(File(photos[0].path)), fit: BoxFit.cover)
                : null,
          ),
          child: Stack(
            children: [
              if (!hasPhoto)
                const Center(
                    child: Icon(Icons.star_border,
                        size: 40, color: Colors.white24)),
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
                    icon: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.red,
                        child:
                            Icon(Icons.close, size: 16, color: Colors.white)),
                    onPressed: () => ref
                        .read(registrationProvider.notifier)
                        .removePhotoAt(0),
                  ),
                ),
              ]
            ],
          ),
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
        image: DecorationImage(
            image: FileImage(File(photo.path)), fit: BoxFit.cover),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 2,
            top: 2,
            child: GestureDetector(
              onTap: () =>
                  ref.read(registrationProvider.notifier).removePhotoAt(index),
              child: const CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, size: 12, color: Colors.white)),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child:
                  _badge('register.photo_index'.tr(args: [index.toString()])),
            ),
          )
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: Colors.black87, borderRadius: BorderRadius.circular(5)),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
