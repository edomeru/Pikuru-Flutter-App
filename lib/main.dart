import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/loginpage.dart';
import 'package:pikuru/main_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:pikuru/services/notification_service.dart';

// Must be top-level — registered before runApp
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Init notification service
  await NotificationService.instance.init();

  // TEMPORARY - just to get your token for testing
  final token = await FirebaseMessaging.instance.getToken();
  debugPrint('════════════════════════════════');
  debugPrint('FCM TOKEN: $token');
  debugPrint('════════════════════════════════');

  // ── iOS Keychain fix ─────────────────────────────────────────────
  // iOS keeps Firebase Auth session in Keychain even after app deletion.
  // We use SharedPreferences (cleared on uninstall) to detect fresh installs
  // and sign out automatically so the login screen always shows.
  final prefs = await SharedPreferences.getInstance();
  final hasLaunchedBefore = prefs.getBool('has_launched_before') ?? false;

  if (!hasLaunchedBefore) {
    // First launch after install — sign out any leftover Keychain session
    await FirebaseAuth.instance.signOut();
    await prefs.setBool('has_launched_before', true);
  }

  runApp(
    // Wrap with ProviderScope for Riverpod
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pikuru',
      debugShowCheckedModeBanner: false,
      // ── Required for FCM tap navigation to work ───────────────────────────
      navigatorKey: NotificationService.navigatorKey,
      theme: ThemeData(
        fontFamily: 'Rubik',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          background: AppColors.background,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ── Splash Screen ─────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _navigateTo(const MainNavigation());
    } else {
      _navigateTo(const LoginScreen());
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/pikuru_full_logo.png',
              width: 160,
              height: 160,
            ),
            const SizedBox(height: 20),
            const Text(
              'Play Pickleball anywhere with Pikuru',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'Rubik',
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}