import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ProfileService {
  static final ValueNotifier<String?> avatarPathNotifier = ValueNotifier<String?>(null);
  static final ImagePicker _picker = ImagePicker();

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
              backgroundColor: const Color(0xFF99CFCF),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Open Settings',
              style: GoogleFonts.poppins(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Pick profile image from phone gallery or camera with explicit runtime permission request
  static Future<void> pickProfileImage(BuildContext context, ImageSource source) async {
    // 1. Explicit Runtime Permission Check
    if (source == ImageSource.camera) {
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied) {
        if (context.mounted) {
          _showPermissionDeniedDialog(context, 'Camera');
        }
        return;
      }
    } else if (source == ImageSource.gallery) {
      PermissionStatus status;
      if (Platform.isAndroid) {
        status = await Permission.photos.request();
        if (status.isDenied) {
          status = await Permission.storage.request();
        }
      } else {
        status = await Permission.photos.request();
      }

      if (status.isPermanentlyDenied) {
        if (context.mounted) {
          _showPermissionDeniedDialog(context, 'Photo Gallery');
        }
        return;
      }
    }

    // 2. Open System Picker / Camera
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        avatarPathNotifier.value = image.path;
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Profile photo updated successfully!',
                style: GoogleFonts.poppins(fontSize: 12.5),
              ),
              backgroundColor: const Color(0xFF0F172A),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking profile image: $e');
    }
  }

  // Remove photo
  static void removeProfileImage() {
    avatarPathNotifier.value = null;
  }

  // Show bottom sheet to choose photo source
  static void showPhotoOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(context).padding.bottom + 20,
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
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0x2899CFCF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF0F172A), size: 22),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  pickProfileImage(context, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0x2899CFCF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0F172A), size: 22),
                ),
                title: Text(
                  'Take a Photo',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  pickProfileImage(context, ImageSource.camera);
                },
              ),
              if (avatarPathNotifier.value != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                  ),
                  title: Text(
                    'Remove Current Photo',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    removeProfileImage();
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
    return ValueListenableBuilder<String?>(
      valueListenable: avatarPathNotifier,
      builder: (context, imagePath, child) {
        return GestureDetector(
          onTap: onTap ?? () => showPhotoOptionsBottomSheet(context),
          child: Stack(
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEBF7F7),
                  border: Border.all(color: const Color(0xFF99CFCF), width: 2),
                ),
                child: ClipOval(
                  child: imagePath != null && File(imagePath).existsSync()
                      ? Image.file(
                          File(imagePath),
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                        )
                      : Icon(
                          Icons.person_rounded,
                          size: size * 0.65,
                          color: const Color(0xFF0F172A),
                        ),
                ),
              ),
              if (showCameraBadge)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF99CFCF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: size * 0.25,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
