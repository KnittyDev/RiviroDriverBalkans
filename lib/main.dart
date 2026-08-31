import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'screens/main_screen.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('🔥 [Firebase] Initialized successfully');
  } catch (e) {
    debugPrint('⚠️ [Firebase] Initialization error: $e');
  }

  // 2. Load Environment Variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }

  // 3. Initialize Supabase
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'https://dpxthqrofxsciaqbmnoq.supabase.co';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRweHRocXJvZnhzY2lhcWJtbm9xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3MjQ3OTAsImV4cCI6MjEwMTMwMDc5MH0.cVjaM5oAxinicaal1BV9D0Qa1JbJolAE5doKjsYH3kA';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // 4. Initialize Push Notifications & FCM Token Sync
  await PushNotificationService.initialize();

  runApp(const RiviloDriverApp());
}

class RiviloDriverApp extends StatelessWidget {
  const RiviloDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rivilo Driver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainScreen(),
    );
  }
}
