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
  final DatabaseReference _database = FirebaseDatabase.instance.ref('lights');
  String _currentMode = 'off';
  double _intensity = 0.5;
  bool _isLoading = false;

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
                // Current light level indicator
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'Current Light Level',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.currentLightLevel} lux',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
