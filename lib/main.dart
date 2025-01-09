import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'screens/sensor_dashboard.dart';
import 'screens/wellness_notification.dart';

Future<void> main() async {
  try {
    // Initialize Flutter bindings for platform channels
    WidgetsFlutterBinding.ensureInitialized();
    
    // Lock screen to portrait mode for consistent UI
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    // Initialize Firebase with platform-specific options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Set up notifications before launching the app
    final notificationManager = WellnessNotificationManager();
    await notificationManager.initializeNotifications();
    
    runApp(const MyApp());
  } catch (e) {
    print('Initialization error: $e');
    // Launch error view if initialization fails
    runApp(const MyApp(hasError: true));
  }
}

class MyApp extends StatelessWidget {
  final bool hasError;
  
  const MyApp({super.key, this.hasError = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensor Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardTheme(
          elevation: 4,
          margin: EdgeInsets.symmetric(vertical: 8),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: hasError ? const _ErrorScreen() : const SensorDashboard(),
    );
  }
}

// Error screen shown when initialization fails
class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to initialize app',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please check your connection and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => main(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}