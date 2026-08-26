import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import '../theme/app_theme.dart';

class ProfileService {
  static final ValueNotifier<String?> avatarPathNotifier = ValueNotifier<String?>(null);
  static final ValueNotifier<bool> isUploadingNotifier = ValueNotifier<bool>(false);
  static final ImagePicker _picker = ImagePicker();

  /// Initialize avatar URL from current driver profile
  static void initFromDriver(DriverProfileModel? driver) {
    if (driver?.avatarUrl != null && driver!.avatarUrl!.isNotEmpty) {
      avatarPathNotifier.value = driver.avatarUrl;
    }
  }

  // Show permission denied alert dialog with button to open system settings
  static void _showPermissionDeniedDialog(BuildContext context, String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: Colors.orangeAccent),
            const SizedBox(width: 10),
            Text(
              'Permission Required',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Rivilo Driver needs $permissionName permission to update your profile photo. Please grant permission in App Settings.',
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Open Settings',
              style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Pick profile image from phone gallery or camera
  static Future<void> pickProfileImage(ImageSource source, [BuildContext? context]) async {
    debugPrint('📸 [ProfileService] pickProfileImage called with source: $source');

    try {
      // 1. Camera permission check only for Camera
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        if (cameraStatus.isPermanentlyDenied) {
          if (context != null && context.mounted) {
            _showPermissionDeniedDialog(context, 'Camera');
          }
          return;
        }
      }

      // 2. Open System Picker / Camera directly (uses Android Photo Picker / iOS Picker)
      debugPrint('🖼️ [ProfileService] Launching ImagePicker for $source...');
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) {
        debugPrint('ℹ️ [ProfileService] User dismissed image picker without selecting an image.');
        return;
      }

      debugPrint('✅ [ProfileService] Image picked: ${image.path} (Name: ${image.name})');

      final file = File(image.path);
      if (!file.existsSync()) {
        debugPrint('❌ [ProfileService] Picked file does not exist at path: ${image.path}');
        return;
      }

      // Instant optimistic preview
      avatarPathNotifier.value = image.path;

      // Always execute upload unconditionally
      await uploadProfilePhoto(file, context);
    } catch (e, stack) {
      debugPrint('❌ [ProfileService] Error picking profile image: $e\n$stack');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Uploads selected photo binary to Supabase Storage 'avatars' bucket & updates database
  static Future<bool> uploadProfilePhoto(File imageFile, [BuildContext? context]) async {
    isUploadingNotifier.value = true;
    debugPrint('🚀 [ProfileService] uploadProfilePhoto started...');

    try {
      DriverProfileModel? driver = AuthService.currentDriverNotifier.value;
      String? driverId = driver?.id ?? Supabase.instance.client.auth.currentUser?.id;

      // Fallback: If session driver is empty, auto-fetch from Supabase
      if (driverId == null || driverId.isEmpty) {
        debugPrint('🔍 [ProfileService] No active driver in memory, querying Supabase profiles for driver...');
        final driverRow = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('role', 'driver')
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (driverRow != null) {
          driverId = driverRow['id'] as String?;
          driver = DriverProfileModel.fromJson(driverRow);
          await AuthService.setCurrentDriver(driver);
          debugPrint('👤 [ProfileService] Auto-connected driver profile: ${driver.fullName} ($driverId)');
        }
      }

      if (driverId == null || driverId.isEmpty) {
        debugPrint('❌ [ProfileService] Could not determine driver ID.');
        isUploadingNotifier.value = false;
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Driver account not found in database.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return false;
      }

      debugPrint('🆔 [ProfileService] Driver ID: $driverId');
      final bytes = await imageFile.readAsBytes();
      final storagePath = '$driverId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

      debugPrint('📤 [ProfileService] Uploading avatar binary (${bytes.length} bytes) to bucket "avatars" at path "$storagePath"...');

      // 1. Upload binary to Supabase Storage private bucket 'avatars'
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      debugPrint('📦 [ProfileService] uploadBinary completed successfully!');

      // 2. Generate long-lived Signed URL (1 year)
      final signedUrl = await Supabase.instance.client.storage
          .from('avatars')
          .createSignedUrl(storagePath, 60 * 60 * 24 * 365);

      debugPrint('🔗 [ProfileService] Generated Signed URL: $signedUrl');

      // 3. Update public.profiles in database
      final updateRes = await Supabase.instance.client.from('profiles').update({
        'avatar_url': signedUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', driverId).select();

      debugPrint('💾 [ProfileService] Supabase profiles updated: $updateRes');

      // 4. Update local driver profile
      if (driver != null) {
        final updatedDriver = driver.copyWith(avatarUrl: signedUrl);
        await AuthService.setCurrentDriver(updatedDriver);
      }

      avatarPathNotifier.value = signedUrl;
      isUploadingNotifier.value = false;

      debugPrint('🎉 [ProfileService] Profile photo successfully uploaded & state updated!');

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Profile photo updated successfully!',
                  style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.white),
                ),
              ],
            ),
            backgroundColor: AppColors.textDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return true;
    } catch (e, stack) {
      debugPrint('❌ [ProfileService] Error uploading profile photo: $e\n$stack');
      isUploadingNotifier.value = false;

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload error: $e',
              style: GoogleFonts.poppins(fontSize: 12.5),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return false;
    }
  }

  // Remove photo from database & state
  static Future<void> removeProfileImage([BuildContext? context]) async {
    final driver = AuthService.currentDriverNotifier.value;
    final driverId = driver?.id ?? Supabase.instance.client.auth.currentUser?.id;

    if (driverId != null) {
      try {
        await Supabase.instance.client.from('profiles').update({
          'avatar_url': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', driverId);

        if (driver != null) {
          final updated = driver.copyWith(avatarUrl: null);
          await AuthService.setCurrentDriver(updated);
        }
      } catch (e) {
        debugPrint('Error removing avatar from DB: $e');
      }
    }

    avatarPathNotifier.value = null;

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile photo removed.',
            style: GoogleFonts.poppins(fontSize: 12.5),
          ),
          backgroundColor: AppColors.textDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  // Show bottom sheet to choose photo source
  static void showPhotoOptionsBottomSheet(BuildContext parentContext) {
    showModalBottomSheet(
      context: parentContext,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(sheetContext).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle Bar
              Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Change Profile Photo',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryActiveBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.textDark, size: 22),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  pickProfileImage(ImageSource.gallery, parentContext);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryActiveBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.textDark, size: 22),
                ),
                title: Text(
                  'Take a Photo',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  pickProfileImage(ImageSource.camera, parentContext);
                },
              ),
              if (avatarPathNotifier.value != null ||
                  AuthService.currentDriverNotifier.value?.avatarUrl != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                  ),
                  title: Text(
                    'Remove Current Photo',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    removeProfileImage(parentContext);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // Build reactive avatar widget
  static Widget buildAvatarWidget({
    required double size,
    bool showCameraBadge = false,
    VoidCallback? onTap,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: isUploadingNotifier,
      builder: (context, isUploading, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: avatarPathNotifier,
          builder: (context, avatarPath, child) {
            final effectiveUrl = avatarPath ?? AuthService.currentDriverNotifier.value?.avatarUrl;

            return GestureDetector(
              onTap: onTap ?? () => showPhotoOptionsBottomSheet(context),
              child: Stack(
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primarySubtle,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 2),
                    ),
                    child: ClipOval(
                      child: isUploading
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.textDark,
                                ),
                              ),
                            )
                          : (effectiveUrl != null && effectiveUrl.isNotEmpty)
                              ? (effectiveUrl.startsWith('http://') || effectiveUrl.startsWith('https://'))
                                  ? Image.network(
                                      effectiveUrl,
                                      width: size,
                                      height: size,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Icon(
                                        Icons.person_rounded,
                                        size: size * 0.60,
                                        color: AppColors.textDark,
                                      ),
                                    )
                                  : File(effectiveUrl).existsSync()
                                      ? Image.file(
                                          File(effectiveUrl),
                                          width: size,
                                          height: size,
                                          fit: BoxFit.cover,
                                        )
                                      : Icon(
                                          Icons.person_rounded,
                                          size: size * 0.60,
                                          color: AppColors.textDark,
                                        )
                              : Icon(
                                  Icons.person_rounded,
                                  size: size * 0.60,
                                  color: AppColors.textDark,
                                ),
                    ),
                  ),
                  if (showCameraBadge && !isUploading)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A0F172A),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: size * 0.24,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
