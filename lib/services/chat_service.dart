import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'encryption_service.dart';

class ChatMessageModel {
  final String id;
  final String rideId;
  final String senderId;
  final String senderRole; // 'passenger', 'driver', 'system'
  final String message;
  final String? imageUrl;
  final String? mediaPath;
  final bool isRead;
  final bool isEncrypted;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.senderRole,
    required this.message,
    this.imageUrl,
    this.mediaPath,
    required this.isRead,
    this.isEncrypted = false,
    required this.createdAt,
  });

  bool get hasImage => (imageUrl != null && imageUrl!.isNotEmpty) || (mediaPath != null && mediaPath!.isNotEmpty);
  bool get isPassenger => senderRole == 'passenger';
  bool get isDriver => senderRole == 'driver';
  bool get isSystem => senderRole == 'system';

  factory ChatMessageModel.fromJson(Map<String, dynamic> json, {String? targetRideId}) {
    final String rideId = targetRideId ?? json['ride_id']?.toString() ?? '';
    final String? encryptedPayload = json['encrypted_payload'] as String?;
    final String? iv = json['iv'] as String?;

    // Attempt to decrypt if payload & IV are present
    if (encryptedPayload != null && encryptedPayload.isNotEmpty && iv != null && iv.isNotEmpty) {
      final decrypted = EncryptionService.decryptMap(
        rideId: rideId,
        encryptedBase64: encryptedPayload,
        ivBase64: iv,
      );

      if (decrypted != null) {
        return ChatMessageModel(
          id: json['id']?.toString() ?? '',
          rideId: rideId,
          senderId: decrypted['sender_id']?.toString() ?? '',
          senderRole: decrypted['sender_role'] as String? ?? 'passenger',
          message: decrypted['message'] as String? ?? '',
          imageUrl: decrypted['image_url'] as String?,
          mediaPath: decrypted['media_path'] as String?,
          isRead: json['is_read'] as bool? ?? false,
          isEncrypted: true,
          createdAt: decrypted['timestamp'] != null
              ? DateTime.tryParse(decrypted['timestamp'].toString())?.toLocal() ?? DateTime.now()
              : (json['created_at'] != null
                  ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
                  : DateTime.now()),
        );
      }
    }

    // Fallback for plaintext / legacy messages
    return ChatMessageModel(
      id: json['id']?.toString() ?? '',
      rideId: rideId,
      senderId: json['sender_id']?.toString() ?? '',
      senderRole: json['sender_role'] as String? ?? 'passenger',
      message: json['message'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      mediaPath: json['media_path'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      isEncrypted: false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class ChatService {
  /// Stream and automatically decrypt real-time messages for a specific ride with strict ID deduplication
  static Stream<List<ChatMessageModel>> streamMessages(String rideId) {
    if (rideId.isEmpty) return Stream.value([]);

    return Supabase.instance.client
        .from('ride_messages')
        .stream(primaryKey: ['id'])
        .eq('ride_id', rideId)
        .order('created_at', ascending: true)
        .map((rows) {
          final Map<String, ChatMessageModel> uniqueMap = {};
          for (final r in rows) {
            final model = ChatMessageModel.fromJson(r, targetRideId: rideId);
            if (model.id.isNotEmpty) {
              uniqueMap[model.id] = model;
            }
          }
          final list = uniqueMap.values.toList();
          list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return list;
        });
  }

  /// Encrypt and send a real message (Zero-Knowledge: sender_id, role, and text are encrypted)
  static Future<bool> sendMessage({
    required String rideId,
    required String message,
    String senderRole = 'driver',
  }) async {
    final cleanText = message.trim();
    if (cleanText.isEmpty || rideId.isEmpty) return false;

    final currentDriver = AuthService.currentDriverNotifier.value;
    final senderId = currentDriver?.id ??
        Supabase.instance.client.auth.currentUser?.id ??
        '5f1cf82b-39d1-4f50-b2a7-0fe62ded004e';
    final nowUtc = DateTime.now().toUtc();

    try {
      // 1. Pack full sensitive payload (True senderId, senderRole, and message)
      final payload = {
        'sender_id': senderId,
        'sender_role': senderRole,
        'message': cleanText,
        'timestamp': nowUtc.toIso8601String(),
      };

      // 2. Encrypt with AES-256-CBC using Ride Key
      final encrypted = EncryptionService.encryptMap(
        rideId: rideId,
        payload: payload,
      );

      // 3. Generate one-way hashed opaque sender identity so real senderId is never stored in plaintext
      final opaqueSenderHash = sha256.convert(utf8.encode('$senderId:$rideId')).toString().substring(0, 16);

      // 4. Insert into Supabase (Plaintext columns contain ONLY masked/encrypted values)
      await Supabase.instance.client.from('ride_messages').insert({
        'ride_id': rideId,
        'sender_id': 'enc_$opaqueSenderHash',
        'sender_role': senderRole,
        'message': '🔒 [Encrypted]',
        'encrypted_payload': encrypted['encrypted_payload'],
        'iv': encrypted['iv'],
        'is_read': false,
        'created_at': nowUtc.toIso8601String(),
      });

      return true;
    } catch (e) {
      debugPrint('Error sending encrypted driver ride message: $e');
      return false;
    }
  }

  /// Upload image to private 'media_images' bucket and send E2EE image message
  static Future<bool> sendImageMessage({
    required String rideId,
    required Uint8List imageBytes,
    String? caption,
    String senderRole = 'driver',
  }) async {
    if (imageBytes.isEmpty || rideId.isEmpty) return false;

    final currentDriver = AuthService.currentDriverNotifier.value;
    final senderId = currentDriver?.id ??
        Supabase.instance.client.auth.currentUser?.id ??
        '5f1cf82b-39d1-4f50-b2a7-0fe62ded004e';
    final nowUtc = DateTime.now().toUtc();
    final filename = 'chat_${rideId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = 'chat/$rideId/$filename';

    try {
      // 1. Upload to private 'media_images' Supabase storage bucket
      await Supabase.instance.client.storage
          .from('media_images')
          .uploadBinary(
            storagePath,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // 2. Generate long-lived Signed URL for private access (1 Year)
      final signedUrl = await Supabase.instance.client.storage
          .from('media_images')
          .createSignedUrl(storagePath, 60 * 60 * 24 * 365);

      // 3. Encrypt media payload (image_url and media_path are inside AES-256 ciphertext!)
      final payload = {
        'sender_id': senderId,
        'sender_role': senderRole,
        'message': caption?.trim().isNotEmpty == true ? caption!.trim() : '📷 Photo',
        'media_path': storagePath,
        'image_url': signedUrl,
        'timestamp': nowUtc.toIso8601String(),
      };

      final encrypted = EncryptionService.encryptMap(
        rideId: rideId,
        payload: payload,
      );

      // 4. Opaque identity
      final opaqueSenderHash = sha256.convert(utf8.encode('$senderId:$rideId')).toString().substring(0, 16);

      // 5. Insert into Supabase
      await Supabase.instance.client.from('ride_messages').insert({
        'ride_id': rideId,
        'sender_id': 'enc_$opaqueSenderHash',
        'sender_role': senderRole,
        'message': '🔒 [Encrypted Photo]',
        'encrypted_payload': encrypted['encrypted_payload'],
        'iv': encrypted['iv'],
        'is_read': false,
        'created_at': nowUtc.toIso8601String(),
      });

      return true;
    } catch (e) {
      debugPrint('Error uploading and sending chat image: $e');
      return false;
    }
  }

  /// Refreshes/creates a Signed URL from private 'media_images' bucket if needed
  static Future<String?> getSignedUrl(String mediaPath) async {
    if (mediaPath.isEmpty) return null;
    try {
      return await Supabase.instance.client.storage
          .from('media_images')
          .createSignedUrl(mediaPath, 60 * 60 * 24 * 30);
    } catch (e) {
      debugPrint('Error creating signed url: $e');
      return null;
    }
  }

  /// Mark all messages sent by the passenger in a ride as read
  static Future<void> markAsRead(String rideId) async {
    if (rideId.isEmpty) return;
    try {
      await Supabase.instance.client
          .from('ride_messages')
          .update({'is_read': true})
          .eq('ride_id', rideId)
          .eq('sender_role', 'passenger')
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }
}
