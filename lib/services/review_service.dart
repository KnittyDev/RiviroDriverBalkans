import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'hot_potato_dispatch_service.dart';
import '../widgets/trip_review_modal.dart';

class ReviewService {
  /// Submit driver's review for the passenger to public.ride_reviews
  static Future<bool> submitPassengerReview({
    required String rideId,
    String? passengerId,
    String? driverId,
    required double rating,
    List<String> feedbackTags = const [],
    String? comment,
  }) async {
    try {
      final effectiveDriverId = driverId ??
          AuthService.currentDriverNotifier.value?.id ??
          Supabase.instance.client.auth.currentUser?.id;

      // 1. If passengerId is not supplied, fetch user_id from the ride
      String? effectivePassengerId = passengerId;
      if (effectivePassengerId == null || effectivePassengerId.isEmpty) {
        final rideRow = await Supabase.instance.client
            .from('rides')
            .select('user_id')
            .eq('id', rideId)
            .maybeSingle();
        if (rideRow != null) {
          effectivePassengerId = rideRow['user_id']?.toString();
        }
      }

      debugPrint('⭐ [ReviewService] Submitting passenger review for ride $rideId (Rating: $rating, Driver: $effectiveDriverId, Passenger: $effectivePassengerId)...');

      // 2. Insert record into ride_reviews table
      await Supabase.instance.client.from('ride_reviews').insert({
        'ride_id': rideId,
        'user_id': effectivePassengerId ?? '',
        'driver_id': effectiveDriverId,
        'rating': rating,
        'feedback_tags': feedbackTags,
        'comment': comment?.trim().isNotEmpty == true ? comment!.trim() : null,
        'reviewer_role': 'driver',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // 3. Mark driver_reviewed = true in rides table
      await Supabase.instance.client.from('rides').update({
        'driver_reviewed': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', rideId);

      debugPrint('✅ [ReviewService] Passenger review submitted successfully!');
      return true;
    } catch (e, stack) {
      debugPrint('❌ [ReviewService] Error submitting passenger review: $e\n$stack');
      return false;
    }
  }

  /// Dismiss passenger review prompt for a ride
  static Future<void> dismissPassengerReview({required String rideId}) async {
    try {
      await Supabase.instance.client.from('rides').update({
        'driver_review_dismissed': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', rideId);
      debugPrint('ℹ️ [ReviewService] Driver review dismissed for ride $rideId');
    } catch (e) {
      debugPrint('Error dismissing driver review: $e');
    }
  }

  /// Calculate average driver rating from passenger reviews
  static Future<double?> fetchDriverAverageRating(String driverId) async {
    try {
      final reviews = await Supabase.instance.client
          .from('ride_reviews')
          .select('rating')
          .eq('driver_id', driverId)
          .or('reviewer_role.eq.rider,reviewer_role.is.null');

      if (reviews.isEmpty) return null;

      double total = 0.0;
      for (final r in reviews) {
        final num? val = r['rating'] as num?;
        if (val != null) total += val.toDouble();
      }
      return double.parse((total / reviews.length).toStringAsFixed(1));
    } catch (e) {
      debugPrint('Error fetching driver average rating: $e');
      return null;
    }
  }

  /// Fetches all reviews given to this driver by riders with passenger profiles
  static Future<List<Map<String, dynamic>>> fetchDriverReviewsList(String driverId) async {
    try {
      final reviews = await Supabase.instance.client
          .from('ride_reviews')
          .select()
          .eq('driver_id', driverId)
          .or('reviewer_role.eq.rider,reviewer_role.is.null')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> enriched = [];
      for (final r in reviews) {
        final map = Map<String, dynamic>.from(r);
        final userId = map['user_id']?.toString();

        if (userId != null && userId.isNotEmpty) {
          try {
            final profile = await Supabase.instance.client
                .from('profiles')
                .select('full_name, avatar_url')
                .eq('id', userId)
                .maybeSingle();

            if (profile != null) {
              map['passenger_name'] = profile['full_name'] ?? 'Passenger';
              map['passenger_avatar_url'] = profile['avatar_url'];
            }
          } catch (_) {}
        }

        if (map['passenger_name'] == null || (map['passenger_name'] as String).isEmpty) {
          map['passenger_name'] = 'Passenger';
        }

        enriched.add(map);
      }
      return enriched;
    } catch (e) {
      debugPrint('Error fetching driver reviews list: $e');
      return [];
    }
  }

  /// Checks if there is an unrated finished ride and opens the Review modal
  static Future<void> checkAndPromptPendingReview(BuildContext context) async {
    final driverId = AuthService.currentDriverNotifier.value?.id ??
        Supabase.instance.client.auth.currentUser?.id;

    if (driverId == null || driverId.isEmpty) return;

    try {
      final pendingRide = await Supabase.instance.client
          .from('rides')
          .select()
          .or('driver_id.eq.$driverId,assigned_driver_id.eq.$driverId')
          .inFilter('status', ['completed', 'finished'])
          .or('driver_reviewed.is.null,driver_reviewed.eq.false')
          .or('driver_review_dismissed.is.null,driver_review_dismissed.eq.false')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (pendingRide != null && context.mounted) {
        final rideId = pendingRide['id']?.toString() ?? '';
        final passengerName = pendingRide['passenger_name']?.toString() ?? 'Passenger';
        final passengerAvatarUrl = pendingRide['passenger_avatar_url']?.toString();
        final fareNum = (pendingRide['fare_amount'] as num?)?.toDouble();
        final fare = CurrencyHelper.formatFare(
          fareNum,
          currencySymbol: pendingRide['currency_symbol']?.toString(),
          currencyCode: pendingRide['currency_code']?.toString(),
        );

        TripReviewModal.show(
          context,
          rideId: rideId,
          passengerName: passengerName,
          passengerAvatarUrl: passengerAvatarUrl,
          fare: fare,
          tripId: '#TR-${rideId.substring(0, 4).toUpperCase()}',
        );
      }
    } catch (e) {
      debugPrint('Error checking pending driver reviews: $e');
    }
  }
}
