import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'orders/orders_screen.dart';
import 'profile/profile_screen.dart';
import '../widgets/custom_bottom_navbar.dart';
import '../services/location_service.dart';
import '../services/battery_optimization_service.dart';
import '../services/supabase_location_tracker_service.dart';
import '../services/auth_service.dart';
import '../services/hot_potato_dispatch_service.dart';
import '../services/review_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  static final ValueNotifier<int> mainTabNotifier = ValueNotifier<int>(0);

  static void switchToTab(int index) {
    mainTabNotifier.value = index;
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<Widget> _screens = const [
    HomeScreen(),
    OrdersScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // 1. Initialize active driver session from SharedPreferences / Supabase
    // 2. Request location permission & prompt native GPS "Turn on" dialog when user opens the app
    // 3. Automatically prompt Power Saver / Battery Optimization dialog on launch
    // 4. Start 50-meter Supabase Location Tracker
    // 5. Start Hot Potato Dispatch Realtime Listener for incoming ride offers
    // 6. Check and prompt unreviewed completed rides
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AuthService.initSavedDriverSession();
      final hasLocation = await LocationService().initAndRequestLocationPermission();
      if (hasLocation) {
        SupabaseLocationTrackerService().startLocationTracking();
      }
      if (mounted) {
        BatteryOptimizationService.checkAndPromptBatteryOptimizationOnStartup(context);
        HotPotatoDispatchService().startListening(context);
        ReviewService.checkAndPromptPendingReview(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: MainScreen.mainTabNotifier,
      builder: (context, currentIndex, _) {
        return Scaffold(
          extendBody: true,
          body: IndexedStack(
            index: currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: CustomBottomNavBar(
            currentIndex: currentIndex,
            onTap: (index) {
              MainScreen.switchToTab(index);
            },
          ),
        );
      },
    );
  }
}
