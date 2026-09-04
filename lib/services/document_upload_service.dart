import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DocumentUploadService {
  static final ImagePicker _picker = ImagePicker();

  /// Picks an image from camera or gallery
  static Future<File?> pickDocumentImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (photo == null) return null;
      return File(photo.path);
    } catch (e) {
      debugPrint('⚠️ [DocumentUploadService] Error picking document: $e');
      return null;
    }
  }

  /// Uploads front or back license photo binary to 'id_verifications' Supabase storage bucket.
  /// Returns the permanent public URL string of the uploaded document.
  static Future<String?> uploadLicenseDocument({
    required File file,
    required String driverId,
    required bool isFront,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final side = isFront ? 'front' : 'back';
      final fileName = 'license_${side}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'licenses/$driverId/$fileName';

      debugPrint('📤 [DocumentUploadService] Uploading $side license to id_verifications at path "$storagePath"...');

      await Supabase.instance.client.storage
          .from('id_verifications')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('id_verifications')
          .getPublicUrl(storagePath);

      debugPrint('✅ [DocumentUploadService] Uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e, stack) {
      debugPrint('❌ [DocumentUploadService] Error uploading license document: $e\n$stack');
      return null;
    }
  }
}
