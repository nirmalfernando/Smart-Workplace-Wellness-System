import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
// import 'package:smart_workplace/screens/heartrate_history.dart';
import 'package:smart_workplace/screens/light_control.dart';
import 'wellness_notification.dart';

class SensorDashboard extends StatefulWidget {
  const SensorDashboard({super.key});

  @override
  State<SensorDashboard> createState() => _SensorDashboardState();
}

class _SensorDashboardState extends State<SensorDashboard> {
  // Database and stream setup
  final DatabaseReference _database = FirebaseDatabase.instance.ref('sensors');
  late final Stream<DatabaseEvent> _lightStream;
  late final Stream<DatabaseEvent> _heartRateStream;
  late final Stream<DatabaseEvent> _soundStream;
  late final Stream<DatabaseEvent> _airQualityStream;
  
  // Notification manager instance
  final WellnessNotificationManager _notificationManager = WellnessNotificationManager();
  
  // UI state tracking
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize all streams as broadcast streams for multiple listeners
      _lightStream = _database.child('light').onValue.asBroadcastStream();
      _heartRateStream = _database.child('heartRate').onValue.asBroadcastStream();
      _soundStream = _database.child('soundLevel').onValue.asBroadcastStream();
      _airQualityStream = _database.child('airQuality').onValue.asBroadcastStream();

      // Set up notification listeners after streams are ready
      _setupNotificationListeners();

      // Mark initialization as complete
      setState(() {
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to initialize sensors: $e';
      });
    }
  }

  void _setupNotificationListeners() {
    // Set up listeners for each sensor type with error handling
    _lightStream.listen(
      (event) => _notificationManager.processSensorReadings(
        lightLevel: event.snapshot.value as int?
      ),
      onError: (error) => print('Light sensor error: $error'),
    );

    _heartRateStream.listen(
      (event) => _notificationManager.processSensorReadings(
        heartRate: event.snapshot.value as int?
      ),
      onError: (error) => print('Heart rate sensor error: $error'),
    );

    _soundStream.listen(
      (event) => _notificationManager.processSensorReadings(
        soundLevel: event.snapshot.value as int?
      ),
      onError: (error) => print('Sound sensor error: $error'),
    );

    _airQualityStream.listen(
      (event) => _notificationManager.processSensorReadings(
        airQuality: event.snapshot.value as int?
      ),
      onError: (error) => print('Air quality sensor error: $error'),
    );
  }

  // Helper functions for air quality display
  String _getAirQualityDescription(int value) {
    if (value < 200) return 'Excellent';
    if (value < 400) return 'Good';
    if (value < 600) return 'Moderate';
    if (value < 800) return 'Poor';
    return 'Hazardous';
  }

  Color _getAirQualityColor(int value) {
    if (value < 200) return Colors.green;
    if (value < 400) return Colors.lightGreen;
    if (value < 600) return Colors.yellow;
    if (value < 800) return Colors.orange;
    return Colors.red;
  }

  // Navigation handlers
  void _navigateToLightControl(int currentValue) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LightControlScreen(
          currentLightLevel: currentValue,
        ),
      ),
    );
  }

  // void _navigateToHeartRateHistory(int currentValue) {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => HeartRateHistoryScreen(
  //         currentHeartRate: currentValue,
  //       ),
  //     ),
  //   );
  // }

  // Reusable sensor card builder
  Widget _buildSensorCard({
    required Stream<DatabaseEvent> stream,
    required String title,
    required IconData icon,
    required Color color,
    required String unit,
    void Function(int value)? onTap,
  }) {
    return Card(
      elevation: 4,
      child: StreamBuilder<DatabaseEvent>(
        stream: stream,
        builder: (context, snapshot) {
          final currentValue = snapshot.hasData ? 
              (snapshot.data!.snapshot.value as int? ?? 0) : 0;

          return InkWell(
            onTap: onTap != null ? () => onTap(currentValue) : null,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (onTap != null) ...[
                        const Spacer(),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                          size: 24,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.hasError)
                    const Text(
                      'Error loading data',
                      style: TextStyle(color: Colors.red),
                    )
                  else if (!snapshot.hasData)
                    const CircularProgressIndicator()
                  else
                    Column(
                      children: [
                        Text(
                          currentValue.toString(),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(unit, style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAirQualityCard() {
    return Card(
      elevation: 4,
      child: StreamBuilder<DatabaseEvent>(
        stream: _airQualityStream,
        builder: (context, snapshot) {
          final value = snapshot.hasData ? 
              (snapshot.data!.snapshot.value as int? ?? 0) : 0;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.air,
                      color: _getAirQualityColor(value),
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Air Quality',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (snapshot.hasError)
                  const Text(
                    'Error loading data',
                    style: TextStyle(color: Colors.red),
                  )
                else if (!snapshot.hasData)
                  const CircularProgressIndicator()
                else
                  Column(
                    children: [
                      Text(
                        value.toString(),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getAirQualityDescription(value),
                        style: TextStyle(
                          color: _getAirQualityColor(value),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: value / 1000,
                        color: _getAirQualityColor(value),
                        backgroundColor: Colors.grey[200],
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeServices,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Dashboard'),
        centerTitle: true,
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: _initializeServices,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildSensorCard(
                stream: _lightStream,
                title: 'Light Intensity',
                icon: Icons.light_mode,
                color: Colors.amber,
                unit: 'lux',
                onTap: _navigateToLightControl,
              ),
              const SizedBox(height: 16),
              _buildSensorCard(
                stream: _heartRateStream,
                title: 'Heart Rate',
                icon: Icons.favorite,
                color: Colors.red,
                unit: 'BPM',
                // onTap: _navigateToHeartRateHistory,
              ),
              const SizedBox(height: 16),
              _buildSensorCard(
                stream: _soundStream,
                title: 'Sound Level',
                icon: Icons.volume_up,
                color: Colors.purple,
                unit: 'dB',
              ),
              const SizedBox(height: 16),
              _buildAirQualityCard(),
            ],
          ),
        ),
      ),
    );
  }
}
