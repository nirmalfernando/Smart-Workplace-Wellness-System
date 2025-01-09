import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';

class WellnessNotificationManager {
  // Singleton pattern to ensure only one instance exists
  static final WellnessNotificationManager _instance = WellnessNotificationManager._internal();
  factory WellnessNotificationManager() => _instance;
  WellnessNotificationManager._internal();

  // Initialize Flutter Local Notifications
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Define threshold values for different sensors
  static const int HIGH_HEART_RATE_THRESHOLD = 100; // BPM
  static const int LOW_LIGHT_THRESHOLD = 300; // lux
  static const int HIGH_LIGHT_THRESHOLD = 1000; // lux
  static const int HIGH_NOISE_THRESHOLD = 80; // dB
  static const int POOR_AIR_QUALITY_THRESHOLD = 600; // AQI

  // Keep track of last notification times to prevent spam
  final Map<String, DateTime> _lastNotificationTimes = {};
  static const Duration NOTIFICATION_COOLDOWN = Duration(minutes: 5);

  // Initialize notifications
  Future<void> initializeNotifications() async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          // Handle notification tap
          print('Notification tapped: ${details.payload}');
        },
      );

      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize notifications: $e');
      // Handle initialization error gracefully
    }
  }

  // Show a local notification with rate limiting
  Future<void> showNotification({
    required String title,
    required String body,
    required String type,
    String? payload,
  }) async {
    if (!_isInitialized) {
      print('Notifications not initialized');
      return;
    }

    // Check cooldown period
    final lastNotification = _lastNotificationTimes[type];
    final now = DateTime.now();
    if (lastNotification != null &&
        now.difference(lastNotification) < NOTIFICATION_COOLDOWN) {
      return;
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        'wellness_channel',
        'Wellness Notifications',
        channelDescription: 'Notifications for workplace wellness system',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        enableLights: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await notificationsPlugin.show(
        now.millisecond, // Unique ID
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      _lastNotificationTimes[type] = now;
    } catch (e) {
      print('Failed to show notification: $e');
    }
  }

  // Show a toast message with error handling
  Future<void> showToast(String message) async {
    try {
      await Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black87,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      print('Failed to show toast: $e');
    }
  }

  // Process sensor readings with proper error handling
  Future<void> processSensorReadings({
    int? heartRate,
    int? lightLevel,
    int? soundLevel,
    int? airQuality,
  }) async {
    try {
      if (heartRate != null && heartRate > HIGH_HEART_RATE_THRESHOLD) {
        await showNotification(
          title: 'High Heart Rate Detected',
          body: 'Your heart rate is elevated. Consider taking a short break to relax.',
          type: 'heart_rate',
        );
        await showToast('💓 High heart rate detected: $heartRate BPM');
      }

      if (lightLevel != null) {
        if (lightLevel < LOW_LIGHT_THRESHOLD) {
          await showToast(
              '💡 Low light conditions detected. Consider increasing brightness.');
        } else if (lightLevel > HIGH_LIGHT_THRESHOLD) {
          await showToast(
              '☀️ High light intensity detected. Consider reducing brightness.');
        }
      }

      if (soundLevel != null && soundLevel > HIGH_NOISE_THRESHOLD) {
        await showNotification(
          title: 'High Noise Level',
          body: 'Consider using headphones or moving to a quieter area.',
          type: 'noise',
        );
        await showToast('🔊 High noise level detected: $soundLevel dB');
      }

      if (airQuality != null && airQuality > POOR_AIR_QUALITY_THRESHOLD) {
        await showNotification(
          title: 'Poor Air Quality',
          body: 'Air quality is deteriorating. Consider ventilating the space.',
          type: 'air_quality',
        );
        await showToast('🌫️ Poor air quality detected: $airQuality');
      }
    } catch (e) {
      print('Error processing sensor readings: $e');
    }
  }
}