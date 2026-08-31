import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'driver_stats_service.dart';

class StripePaymentResult {
  final bool isSuccess;
  final String? paymentIntentId;
  final String? errorMessage;
  final double? amountPaid;

  const StripePaymentResult({
    required this.isSuccess,
    this.paymentIntentId,
    this.errorMessage,
    this.amountPaid,
  });
}

class StripeService {
  static const String _stripeApiUrl = 'https://api.stripe.com/v1';

  /// Returns the Stripe Secret Key strictly from .env
  static String get secretKey => dotenv.env['STRIPE_SECRET_KEY']?.trim() ?? '';

  /// Returns the Stripe Publishable Key strictly from .env
  static String get publishableKey => dotenv.env['STRIPE_PUBLISHABLE_KEY']?.trim() ?? '';

  /// Checks if Stripe keys are configured in .env
  static bool get isConfigured =>
      secretKey.isNotEmpty && publishableKey.isNotEmpty;

  /// Processes a direct card payment intent via Stripe API and credits the driver's wallet.
  static Future<StripePaymentResult> processDebtSettlement({
    required String driverId,
    required double amount,
    required String cardNumber,
    required String expMonth,
    required String expYear,
    required String cvc,
    String? cardHolderName,
    String currency = 'eur',
  }) async {
    if (amount <= 0) {
      return const StripePaymentResult(
        isSuccess: false,
        errorMessage: 'Invalid payment amount.',
      );
    }

    if (!isConfigured) {
      debugPrint('⚠️ [StripeService] Stripe keys are not configured in .env file!');
      return const StripePaymentResult(
        isSuccess: false,
        errorMessage:
            'Stripe API keys are missing in .env. Please configure STRIPE_SECRET_KEY and STRIPE_PUBLISHABLE_KEY.',
      );
    }

    try {
      debugPrint('💳 [StripeService] Initiating Stripe payment for driver $driverId with amount €${amount.toStringAsFixed(2)}...');

      final cleanCardNumber = cardNumber.replaceAll(RegExp(r'\s+'), '');
      final int amountInCents = (amount * 100).round();

      // Step 1: Create a Stripe Card Token using the Publishable Key (PCI compliant)
      final tokenUri = Uri.parse('$_stripeApiUrl/tokens');
      final tokenResponse = await http.post(
        tokenUri,
        headers: {
          'Authorization': 'Bearer $publishableKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'card[number]': cleanCardNumber,
          'card[exp_month]': expMonth.trim(),
          'card[exp_year]': expYear.trim(),
          'card[cvc]': cvc.trim(),
          if (cardHolderName != null && cardHolderName.trim().isNotEmpty)
            'card[name]': cardHolderName.trim(),
        },
      );

      final tokenBody = jsonDecode(tokenResponse.body) as Map<String, dynamic>;

      if (tokenResponse.statusCode != 200) {
        final errorMap = tokenBody['error'] as Map<String, dynamic>?;
        final errorMsg = errorMap?['message']?.toString() ?? 'Invalid card details. Please check and try again.';
        debugPrint('❌ [StripeService] Stripe Token Error: $errorMsg');
        return StripePaymentResult(
          isSuccess: false,
          errorMessage: errorMsg,
        );
      }

      final String tokenId = tokenBody['id']?.toString() ?? '';
      debugPrint('✅ [StripeService] Token generated: $tokenId');

      // Step 2: Create and confirm PaymentIntent using the generated token and Secret Key
      final intentUri = Uri.parse('$_stripeApiUrl/payment_intents');
      final intentResponse = await http.post(
        intentUri,
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': amountInCents.toString(),
          'currency': currency.toLowerCase(),
          'payment_method_data[type]': 'card',
          'payment_method_data[card][token]': tokenId,
          'confirm': 'true',
          'description': 'Rivilo Driver Debt Settlement - Driver: $driverId',
          'return_url': 'https://rivilo.com/payment_complete',
        },
      );

      final responseBody = jsonDecode(intentResponse.body) as Map<String, dynamic>;

      if (intentResponse.statusCode != 200) {
        final errorMap = responseBody['error'] as Map<String, dynamic>?;
        final errorMsg = errorMap?['message']?.toString() ?? 'Stripe payment failed. Please check your card details.';
        debugPrint('❌ [StripeService] Stripe PaymentIntent Error: $errorMsg');
        return StripePaymentResult(
          isSuccess: false,
          errorMessage: errorMsg,
        );
      }

      final String paymentIntentId = responseBody['id']?.toString() ?? '';
      final String status = responseBody['status']?.toString() ?? '';

      debugPrint('✅ [StripeService] Stripe PaymentIntent confirmed! ID: $paymentIntentId, Status: $status');

      if (status != 'succeeded' && status != 'requires_capture') {
        return StripePaymentResult(
          isSuccess: false,
          paymentIntentId: paymentIntentId,
          errorMessage: 'Payment status is $status. Please try again or use another card.',
        );
      }

      // 2. Credit the driver_wallet in Supabase profiles
      final profileRow = await Supabase.instance.client
          .from('profiles')
          .select('driver_wallet')
          .eq('id', driverId)
          .maybeSingle();

      final double currentWallet = (profileRow?['driver_wallet'] as num?)?.toDouble() ?? 0.0;
      final double updatedWallet = currentWallet + amount;

      await Supabase.instance.client.from('profiles').update({
        'driver_wallet': updatedWallet,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', driverId);

      // 3. Record transaction in wallet_transactions
      await Supabase.instance.client.from('wallet_transactions').insert({
        'user_id': driverId,
        'type': 'deposit',
        'amount': amount,
        'currency': '€',
        'title': 'Online Pay Settlement',
        'subtitle': 'Card payment • Ref #${paymentIntentId.length >= 8 ? paymentIntentId.substring(paymentIntentId.length - 8) : paymentIntentId}',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // 4. Refresh driver live stats
      await DriverStatsService.fetchDriverLiveStats(driverId);

      return StripePaymentResult(
        isSuccess: true,
        paymentIntentId: paymentIntentId,
        amountPaid: amount,
      );
    } catch (e, stack) {
      debugPrint('❌ [StripeService] Exception during payment: $e\n$stack');
      return StripePaymentResult(
        isSuccess: false,
        errorMessage: 'Network or payment error: $e',
      );
    }
  }
}
