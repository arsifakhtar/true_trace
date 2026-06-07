import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/ble_service.dart';
import 'services/telemetry_service.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/telemetry_upload_service.dart';
import 'services/background_service.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/device_registration_screen.dart';
import 'screens/lost_mode_screen.dart';
import 'screens/finder_mode_screen.dart';
import 'screens/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize notification service
  await NotificationService.initialize();
  
  // Initialize telemetry upload service (WorkManager) - DISABLED DUE TO COMPATIBILITY
  // await TelemetryUploadService.initialize();
  // await TelemetryUploadService.registerPeriodicUpload();

  // Initialize Background Service for Finder Mode
  await BackgroundService.initialize();

  runApp(const TrueTraceApp());
}

class TrueTraceApp extends StatelessWidget {
  const TrueTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleService()),
        ChangeNotifierProvider(create: (_) => TelemetryService()),
        Provider(create: (_) => ApiService(baseUrl: "http://192.168.29.195:8080")),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "TrueTrace",
        home: const AuthWrapper(),
        routes: {
          "/login": (_) => const LoginScreen(),
          "/register": (_) => const DeviceRegistrationScreen(),
          "/home": (_) => const HomeScreen(),
          "/lost": (_) => const LostModeScreen(),
          "/finder": (_) => const FinderModeScreen(),
          "/map": (_) => const MapScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LoginScreen();
        }
        return const HomeScreen();  // ⭐ Now HomeScreen can access Providers
      },
    );
  }
}
