import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'online_duration_service.dart';
import 'profile_service.dart';
import 'push_notification_service.dart';

class DriverProfileModel {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String role;
  final bool isOnline;
  final double? currentLat;
  final double? currentLng;
  final String? avatarUrl;
  final String accountCountry;

  DriverProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.role = 'driver',
    this.isOnline = false,
    this.currentLat,
    this.currentLng,
    this.avatarUrl,
    this.accountCountry = 'ME',
  });

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    return DriverProfileModel(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? json['fullName'] ?? 'Driver',
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'] ?? json['phoneNumber'] ?? '',
      role: json['role'] ?? 'driver',
      isOnline: json['is_online'] == true || json['isOnline'] == true,
      currentLat: json['current_lat'] != null ? (json['current_lat'] as num).toDouble() : null,
      currentLng: json['current_lng'] != null ? (json['current_lng'] as num).toDouble() : null,
      avatarUrl: json['avatar_url'] as String?,
      accountCountry: (json['account_country'] ?? json['accountCountry'] ?? 'ME').toString().toUpperCase(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
      'role': role,
      'is_online': isOnline,
      'current_lat': currentLat,
      'current_lng': currentLng,
      'avatar_url': avatarUrl,
      'account_country': accountCountry,
    };
  }

  DriverProfileModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? role,
    bool? isOnline,
    double? currentLat,
    double? currentLng,
    String? avatarUrl,
  }) {
    return DriverProfileModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      isOnline: isOnline ?? this.isOnline,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class AuthService {
  static const String _prefKey = 'active_driver_profile_v1';

  static final ValueNotifier<DriverProfileModel?> currentDriverNotifier =
      ValueNotifier<DriverProfileModel?>(null);

  /// Updates driver online/offline status in Supabase and local state
  static Future<bool> updateOnlineStatus(bool isOnline) async {
    final current = currentDriverNotifier.value;
    final driverId = current?.id ?? Supabase.instance.client.auth.currentUser?.id;

    if (driverId == null || driverId.isEmpty) {
      debugPrint('⚠️ [AuthService] Cannot update online status: No active driver ID.');
      return false;
    }

    // Check debt threshold if trying to go online
    if (isOnline) {
      try {
        final profileRow = await Supabase.instance.client
            .from('profiles')
            .select('driver_wallet')
            .eq('id', driverId)
            .maybeSingle();

        final double walletBalance = (profileRow?['driver_wallet'] as num?)?.toDouble() ?? 0.0;
        if (walletBalance <= -30.0) {
          debugPrint('🚫 [AuthService] Driver $driverId cannot go online! Debt limit reached: $walletBalance€ <= -30.0€');
          
          final blockedProfile = current != null
              ? current.copyWith(isOnline: false)
              : DriverProfileModel(
                  id: driverId,
                  fullName: 'Driver',
                  email: '',
                  phoneNumber: '',
                  isOnline: false,
                );
          await setCurrentDriver(blockedProfile);
          return false;
        }
      } catch (e) {
        debugPrint('⚠️ [AuthService] Failed checking wallet balance: $e');
      }
    }

    final updatedProfile = current != null
        ? current.copyWith(isOnline: isOnline)
        : DriverProfileModel(
            id: driverId,
            fullName: 'Driver',
            email: '',
            phoneNumber: '',
            isOnline: isOnline,
          );

    await setCurrentDriver(updatedProfile);
    OnlineDurationService.onOnlineStatusChanged(isOnline);

    try {
      final nowUtcIso = DateTime.now().toUtc().toIso8601String();
      await Supabase.instance.client.from('profiles').update({
        'is_online': isOnline,
        'updated_at': nowUtcIso,
      }).eq('id', driverId);

      debugPrint('🟢 [Supabase Status] Driver $driverId status updated: is_online = $isOnline');
      return true;
    } catch (e) {
      debugPrint('❌ [Supabase Status Error]: $e');
      return false;
    }
  }

  static String get _supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'https://dpxthqrofxsciaqbmnoq.supabase.co';
  static String get _supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRweHRocXJvZnhzY2lhcWJtbm9xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3MjQ3OTAsImV4cCI6MjEwMTMwMDc5MH0.cVjaM5oAxinicaal1BV9D0Qa1JbJolAE5doKjsYH3kA';

  /// Initializes saved driver session from Supabase Auth / local storage
  static Future<void> initSavedDriverSession() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        final profileData = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', currentUser.id)
            .maybeSingle();

        if (profileData != null) {
          final profile = DriverProfileModel.fromJson(profileData);
          await setCurrentDriver(profile);
          debugPrint('👤 [Supabase Auth] Session restored: ${profile.fullName} (${profile.id})');
          return;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_prefKey);
      if (savedJson != null && savedJson.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(savedJson);
        final profile = DriverProfileModel.fromJson(map);
        await setCurrentDriver(profile);
        debugPrint('👤 [AuthService] Loaded saved driver session: ${profile.fullName} (${profile.id})');
        return;
      }

      // Auto-connect to active driver in Supabase if no session stored
      final driverRow = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('role', 'driver')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (driverRow != null) {
        final profile = DriverProfileModel.fromJson(driverRow);
        await setCurrentDriver(profile);
        debugPrint('👤 [AuthService] Auto-connected active driver: ${profile.fullName} (${profile.id})');
        return;
      }
    } catch (e) {
      debugPrint('Error loading saved driver session: $e');
    }
  }

  /// Saves the active driver session locally and updates reactive notifier
  static Future<void> setCurrentDriver(DriverProfileModel profile) async {
    currentDriverNotifier.value = profile;
    ProfileService.initFromDriver(profile);
    OnlineDurationService.init(isCurrentlyOnline: profile.isOnline);
    PushNotificationService.syncTokenWithSupabase();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(profile.toJson()));
    } catch (e) {
      debugPrint('Error saving driver session: $e');
    }
  }

  /// Registers a new Driver using 100% authentic Supabase Auth
  static Future<bool> registerDriver({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    try {
      // 1. Official Supabase Auth Sign Up
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone_number': phoneNumber,
          'role': 'driver',
        },
      );

      final user = authResponse.user;
      if (user == null) {
        debugPrint('⚠️ [Supabase Auth] Sign up succeeded but user object is null.');
        return false;
      }

      final userId = user.id; // Authentic Supabase Auth User UUID
      final nowUtcIso = DateTime.now().toUtc().toIso8601String();

      // 2. Insert into public.profiles table using authentic Supabase User UUID
      await Supabase.instance.client.from('profiles').upsert({
        'id': userId,
        'full_name': fullName,
        'email': email,
        'phone_number': phoneNumber,
        'role': 'driver',
        'created_at': nowUtcIso,
        'updated_at': nowUtcIso,
      });

      final newProfile = DriverProfileModel(
        id: userId,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        role: 'driver',
      );

      await setCurrentDriver(newProfile);
      debugPrint('✅ [Supabase Auth] Official Driver Registered: ${user.email} (UUID: $userId)');
      return true;
    } catch (e) {
      debugPrint('❌ [Supabase Auth Register Error]: $e');
      return false;
    }
  }

  /// Logs in an existing Driver using official Supabase Auth
  static Future<bool> loginDriver({
    required String emailOrPhone,
    required String password,
  }) async {
    try {
      final isEmail = emailOrPhone.contains('@');
      AuthResponse authResponse;

      if (isEmail) {
        authResponse = await Supabase.instance.client.auth.signInWithPassword(
          email: emailOrPhone,
          password: password,
        );
      } else {
        authResponse = await Supabase.instance.client.auth.signInWithPassword(
          phone: emailOrPhone,
          password: password,
        );
      }

      final user = authResponse.user;
      if (user != null) {
        final profileData = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        DriverProfileModel profile;
        if (profileData != null) {
          profile = DriverProfileModel.fromJson(profileData);
        } else {
          final userMetadata = user.userMetadata ?? {};
          profile = DriverProfileModel(
            id: user.id,
            fullName: userMetadata['full_name'] ?? 'Driver',
            email: user.email ?? emailOrPhone,
            phoneNumber: userMetadata['phone_number'] ?? user.phone ?? '',
            role: 'driver',
          );

          // Upsert missing profile
          final nowUtcIso = DateTime.now().toUtc().toIso8601String();
          await Supabase.instance.client.from('profiles').upsert({
            'id': user.id,
            'full_name': profile.fullName,
            'email': profile.email,
            'phone_number': profile.phoneNumber,
            'role': 'driver',
            'updated_at': nowUtcIso,
          });
        }

        await setCurrentDriver(profile);
        debugPrint('✅ [Supabase Auth] Official Driver Logged In: ${profile.fullName} (UUID: ${user.id})');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ [Supabase Auth Login Error]: $e');
      return false;
    }
  }

  /// Logout
  static Future<void> logout() async {
    currentDriverNotifier.value = null;
    try {
      await Supabase.instance.client.auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (e) {
      debugPrint('Error clearing driver session: $e');
    }
  }
}
