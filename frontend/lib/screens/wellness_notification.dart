import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:typed_data';

/// A comprehensive manager for handling wellness-related notifications in a Flutter application.
/// This class follows the singleton pattern to ensure a single point of control for all notifications.
/// It handles different types of wellness alerts including heart rate, light levels, sound levels,
/// and air quality, with support for both urgent and normal priority notifications.
class WellnessNotificationManager {
  // Singleton pattern implementation
  static final WellnessNotificationManager _instance = WellnessNotificationManager._internal();
  factory WellnessNotificationManager() => _instance;
  WellnessNotificationManager._internal();

  // Core notification plugin instance and initialization state tracker
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Wellness monitoring thresholds
  // These values can be adjusted based on specific requirements or user preferences
  static const int HIGH_HEART_RATE_THRESHOLD = 100;    // BPM
  static const int LOW_LIGHT_THRESHOLD = 300;          // lux
  static const int HIGH_LIGHT_THRESHOLD = 1000;        // lux
  static const int HIGH_NOISE_THRESHOLD = 80;          // dB
  static const int POOR_AIR_QUALITY_THRESHOLD = 600;   // AQI

  // Time-based notification controls
  static const Duration NOTIFICATION_COOLDOWN = Duration(minutes: 5);
  final Map<String, DateTime> _lastNotificationTimes = {};

  // Vibration patterns defined using Int64List for Android compatibility
  static final Int64List URGENT_VIBRATION_PATTERN = Int64List.fromList([0, 500, 200, 500]);
  static final Int64List NORMAL_VIBRATION_PATTERN = Int64List.fromList([0, 250, 250, 250]);

  /// Initializes the notification system with proper channel configuration
  /// This method should be called when the application starts
  Future<void> initializeNotifications() async {
    // Prevent multiple initializations
    if (_isInitialized) return;

    try {
      // Configure Android settings
      final AndroidInitializationSettings androidSettings = 
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Get Android-specific plugin implementation
      final androidPlugin = notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // Check existing channels to avoid duplication
        final existingChannels = await androidPlugin.getNotificationChannels();
        
        // Create urgent channel if it doesn't exist
        if (existingChannels != null && !existingChannels.any((channel) => channel.id == 'wellness_urgent_channel')) {
          await androidPlugin.createNotificationChannel(
            AndroidNotificationChannel(
              'wellness_urgent_channel',
              'Urgent Wellness Alerts',
              description: 'Critical wellness alerts that require immediate attention',
              importance: Importance.high,
              enableVibration: true,
              playSound: true,
              enableLights: true,
              showBadge: true,
            ),
          );
        }

        // Create normal channel if it doesn't exist
        if (existingChannels != null && !existingChannels.any((channel) => channel.id == 'wellness_normal_channel')) {
          await androidPlugin.createNotificationChannel(
            AndroidNotificationChannel(
              'wellness_normal_channel',
              'Wellness Updates',
              description: 'Regular wellness monitoring updates',
              importance: Importance.defaultImportance,
              enableVibration: true,
              playSound: true,
              enableLights: true,
            ),
          );
        }
      }

      // Configure iOS settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentAlert: true,
        defaultPresentSound: true,
        defaultPresentBadge: true,
      );

      // Combine platform-specific settings
      final initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize the plugin with notification interaction handling
      await notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _handleNotificationTap,
      );

      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize notifications: $e');
      rethrow;
    }
  }

  /// Handles user interaction with notifications
  /// This method is called when a user taps on a notification
  void _handleNotificationTap(NotificationResponse details) {
    final payload = details.payload;
    if (payload == null) return;

    // Handle different types of notifications
    switch (payload) {
      case 'heart_rate':
        print('Heart rate notification tapped');
        // Add navigation or specific actions here
        break;
      case 'air_quality':
        print('Air quality notification tapped');
        // Add navigation or specific actions here
        break;
      // Add more cases as needed
    }
  }

  /// Shows a notification with the specified details
  /// Handles both urgent and normal priority notifications with appropriate settings
  Future<void> showNotification({
    required String title,
    required String body,
    required String type,
    required bool isUrgent,
    String? payload,
  }) async {
    if (!_isInitialized) {
      print('Notifications not initialized');
      return;
    }

    // Implement rate limiting
    final lastNotification = _lastNotificationTimes[type];
    final now = DateTime.now();
    if (lastNotification != null &&
        now.difference(lastNotification) < NOTIFICATION_COOLDOWN) {
      return;
    }

    try {
      // Configure Android notification details
      final androidDetails = AndroidNotificationDetails(
        isUrgent ? 'wellness_urgent_channel' : 'wellness_normal_channel',
        isUrgent ? 'Urgent Wellness Alerts' : 'Wellness Updates',
        channelDescription: isUrgent
            ? 'Critical wellness alerts that require immediate attention'
            : 'Regular wellness monitoring updates',
        importance: isUrgent ? Importance.high : Importance.defaultImportance,
        priority: isUrgent ? Priority.high : Priority.defaultPriority,
        enableVibration: true,
        vibrationPattern: isUrgent ? URGENT_VIBRATION_PATTERN : NORMAL_VIBRATION_PATTERN,
        enableLights: true,
        fullScreenIntent: isUrgent,
      );

      // Configure iOS notification details
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: isUrgent
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
      );

      // Combine platform-specific details
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Show the notification
      await notificationsPlugin.show(
        now.millisecond,  // Unique ID based on current time
        title,
        body,
        notificationDetails,
        payload: payload ?? type,
      );

      // Update rate limiting tracker
      _lastNotificationTimes[type] = now;
    } catch (e) {
      print('Failed to show notification: $e');
      rethrow;
    }
  }

  /// Processes sensor readings and triggers appropriate notifications
  /// This method should be called whenever new sensor data is available
  Future<void> processSensorReadings({
    int? heartRate,
    int? lightLevel,
    int? soundLevel,
    int? airQuality,
  }) async {
    try {
      // Check heart rate
      if (heartRate != null && heartRate > HIGH_HEART_RATE_THRESHOLD) {
        await showNotification(
          title: '⚠️ High Heart Rate Alert',
          body: 'Your heart rate is elevated ($heartRate BPM). Consider taking a break.',
          type: 'heart_rate',
          isUrgent: true,
          payload: 'heart_rate',
        );
      }

      // Check light levels
      if (lightLevel != null) {
        if (lightLevel < LOW_LIGHT_THRESHOLD) {
          await showNotification(
            title: '💡 Low Light Warning',
            body: 'Current light level may strain your eyes. Consider increasing brightness.',
            type: 'light',
            isUrgent: false,
          );
        } else if (lightLevel > HIGH_LIGHT_THRESHOLD) {
          await showNotification(
            title: '☀️ High Light Warning',
            body: 'Excessive brightness detected. Consider reducing light intensity.',
            type: 'light',
            isUrgent: false,
          );
        }
      }

      // Check noise levels
      if (soundLevel != null && soundLevel > HIGH_NOISE_THRESHOLD) {
        await showNotification(
          title: '🔊 High Noise Alert',
          body: 'Noise levels exceed recommended limits ($soundLevel dB)',
          type: 'noise',
          isUrgent: true,
        );
      }

      // Check air quality
      if (airQuality != null && airQuality > POOR_AIR_QUALITY_THRESHOLD) {
        await showNotification(
          title: '🌫️ Poor Air Quality Alert',
          body: 'Air quality is deteriorating (AQI: $airQuality). Ventilate the space.',
          type: 'air_quality',
          isUrgent: true,
        );
      }
    } catch (e) {
      print('Error processing sensor readings: $e');
      rethrow;
    }
  }
}
