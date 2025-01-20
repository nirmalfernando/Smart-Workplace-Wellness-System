import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class LightControlScreen extends StatefulWidget {
  final int currentLightLevel;

  const LightControlScreen({
    super.key,
    required this.currentLightLevel,
  });

  @override
  State<LightControlScreen> createState() => _LightControlScreenState();
}

class _LightControlScreenState extends State<LightControlScreen> {
  // Database references for both controls and sensor readings
  final DatabaseReference _database = FirebaseDatabase.instance.ref('lights');
  final DatabaseReference _sensorDatabase = FirebaseDatabase.instance.ref('sensors');
  
  // Stream for real-time light sensor updates
  late final Stream<DatabaseEvent> _lightStream;
  
  String _currentMode = 'off';
  double _intensity = 0.5;
  bool _isLoading = false;
  
  // Track the latest sensor reading
  int _currentLightLevel = 0;
  bool _hasStreamError = false;

  @override
  void initState() {
    super.initState();
    _currentLightLevel = widget.currentLightLevel;
    _initializeStream();
  }

  void _initializeStream() {
    // Set up the stream as a broadcast stream for multiple listeners
    _lightStream = _sensorDatabase.child('light')
        .onValue
        .asBroadcastStream();

    // Listen to the stream for updates
    _lightStream.listen(
      (event) {
        setState(() {
          _currentLightLevel = event.snapshot.value as int? ?? 0;
          _hasStreamError = false;
        });
      },
      onError: (error) {
        setState(() {
          _hasStreamError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error receiving sensor updates: $error')),
        );
      },
    );
  }

  Future<void> _updateLightSettings(String mode, [double? intensity]) async {
    setState(() => _isLoading = true);
    try {
      await _database.set({
        'mode': mode,
        'intensity': intensity ?? _intensity,
        'timestamp': ServerValue.timestamp,
      });
      setState(() {
        _currentMode = mode;
        if (intensity != null) _intensity = intensity;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update lights: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildModeCard(String title, IconData icon, String mode, Color color) {
    final isSelected = _currentMode == mode;
    return Card(
      elevation: isSelected ? 8 : 4,
      child: InkWell(
        onTap: _isLoading ? null : () => _updateLightSettings(mode),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(color: color, width: 2)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // New widget to display real-time light level with animation
  Widget _buildLightLevelIndicator() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.light_mode,
                  color: Colors.amber,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Light Intensity',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_hasStreamError)
              const Text(
                'Error receiving updates',
                style: TextStyle(color: Colors.red),
              )
            else
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: widget.currentLightLevel.toDouble(),
                  end: _currentLightLevel.toDouble(),
                ),
                duration: const Duration(milliseconds: 500),
                builder: (context, value, child) {
                  return Column(
                    children: [
                      Text(
                        '${value.round()} lux',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: value / 1000, // Assuming max value of 1000 lux
                        backgroundColor: Colors.grey[200],
                        color: Colors.amber,
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Light Control'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Real-time light level indicator
                _buildLightLevelIndicator(),
                const SizedBox(height: 24),
                
                // Light mode selection
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _buildModeCard(
                      'Off',
                      Icons.lightbulb_outline,
                      'off',
                      Colors.grey,
                    ),
                    _buildModeCard(
                      'White Light',
                      Icons.lightbulb,
                      'white',
                      Colors.amber,
                    ),
                    _buildModeCard(
                      'Warm Light',
                      Icons.wb_sunny,
                      'warm',
                      Colors.orange,
                    ),
                    _buildModeCard(
                      'Auto',
                      Icons.auto_mode,
                      'auto',
                      Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Intensity slider
                if (_currentMode != 'off')
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Intensity',
                            style: TextStyle(fontSize: 16),
                          ),
                          Slider(
                            value: _intensity,
                            onChanged: _isLoading
                                ? null
                                : (value) => _updateLightSettings(_currentMode, value),
                            divisions: 10,
                            label: '${(_intensity * 100).round()}%',
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
