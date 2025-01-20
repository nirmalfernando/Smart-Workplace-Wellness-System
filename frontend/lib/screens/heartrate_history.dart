import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';

class HeartRateHistoryScreen extends StatefulWidget {
  final int currentHeartRate;

  const HeartRateHistoryScreen({
    super.key,
    required this.currentHeartRate,
  });

  @override
  State<HeartRateHistoryScreen> createState() => _HeartRateHistoryScreenState();
}

class _HeartRateHistoryScreenState extends State<HeartRateHistoryScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref('sensors');
  List<FlSpot> _dataPoints = [];
  bool _isLoading = true;
  String _selectedTimeRange = '1h';
  double _maxRate = 0;
  double _minRate = 0;
  double _avgRate = 0;
  // Track the current heart rate for real-time display
  late int _currentHeartRate;
  StreamSubscription<DatabaseEvent>? _heartRateSubscription;
  StreamSubscription<DatabaseEvent>? _historySubscription;

  @override
  void initState() {
    super.initState();
    // Initialize current heart rate with the passed value
    _currentHeartRate = widget.currentHeartRate;
    _setupRealtimeUpdates();
  }

  @override
  void dispose() {
    _heartRateSubscription?.cancel();
    _historySubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeUpdates() {
    // Listen to current heart rate
    _heartRateSubscription?.cancel();
    _heartRateSubscription = _database
        .child('heartRate')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        final newRate = event.snapshot.value as int;
        setState(() {
          _currentHeartRate = newRate;
          // Store the new data point immediately
          _storeHistoricalData(newRate);
        });
      }
    });

    // Load historical data
    _loadHistoricalData();
  }

  Future<void> _storeHistoricalData(int heartRate) async {
    try {
      // Store the new heart rate with current timestamp
      await _database.child('heartRateHistory').push().set({
        'timestamp': ServerValue.timestamp,
        'value': heartRate,
      });
    } catch (e) {
      print('Error storing historical data: $e');
    }
  }

  void _loadHistoricalData() {
    final now = DateTime.now();
    final startTime = _getStartTime(now);

    _historySubscription?.cancel();
    _historySubscription = _database
        .child('heartRateHistory')
        .orderByChild('timestamp')
        .startAt(startTime.millisecondsSinceEpoch)
        .onValue
        .listen(
          _processHistoryData,
          onError: (error) {
            print('Error loading heart rate history: $error');
            _handleError(error.toString());
          },
        );
  }

  DateTime _getStartTime(DateTime now) {
    switch (_selectedTimeRange) {
      case '1h':
        return now.subtract(const Duration(hours: 1));
      case '24h':
        return now.subtract(const Duration(hours: 24));
      case '7d':
        return now.subtract(const Duration(days: 7));
      default:
        return now.subtract(const Duration(hours: 1));
    }
  }

  void _processHistoryData(DatabaseEvent event) {
    try {
      final List<FlSpot> points = [];
      double sum = 0;
      double max = 0;
      double min = double.infinity;

      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map;
        data.forEach((key, value) {
          if (value is Map) {
            final timestamp = (value['timestamp'] as int).toDouble();
            final rate = (value['value'] as int).toDouble();
            
            final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
            final timeValue = _selectedTimeRange == '1h' 
                ? date.hour + (date.minute / 60)
                : _selectedTimeRange == '24h'
                    ? date.hour.toDouble()
                    : date.weekday.toDouble();
            
            points.add(FlSpot(timeValue, rate));
            sum += rate;
            max = max > rate ? max : rate;
            min = min < rate ? min : rate;
          }
        });
      }

      setState(() {
        _dataPoints = points..sort((a, b) => a.x.compareTo(b.x));
        _maxRate = max;
        _minRate = min == double.infinity ? 0 : min;
        _avgRate = points.isEmpty ? 0 : sum / points.length;
        _isLoading = false;
      });
    } catch (e) {
      _handleError('Error processing data: $e');
    }
  }

  void _handleError(String errorMessage) {
    setState(() {
      _isLoading = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  void _updateTimeRange(String newRange) {
    setState(() {
      _selectedTimeRange = newRange;
      _isLoading = true;
    });
    _loadHistoricalData();
  }

  // Enhanced current heart rate display with status
  Widget _buildCurrentHeartRateCard() {
    String status;
    Color statusColor;
    
    if (_currentHeartRate < 60) {
      status = 'Low';
      statusColor = Colors.blue;
    } else if (_currentHeartRate < 100) {
      status = 'Normal';
      statusColor = Colors.green;
    } else if (_currentHeartRate < 140) {
      status = 'Elevated';
      statusColor = Colors.orange;
    } else {
      status = 'High';
      statusColor = Colors.red;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text(
                  'Current Heart Rate',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$_currentHeartRate BPM',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, double value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '${value.round()} BPM',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (_dataPoints.isEmpty) {
      return const Center(
        child: Text('No data available for selected time range'),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 20,
          verticalInterval: 1,
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: _selectedTimeRange == '1h' ? 0.25 : 1,
              getTitlesWidget: (value, meta) {
                final text = _selectedTimeRange == '7d'
                    ? ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][value.toInt()]
                    : '${value.toInt()}:00';
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
              reservedSize: 30,
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: _dataPoints,
            isCurved: true,
            color: Colors.red,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: Colors.red,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.red.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Rate History'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCurrentHeartRateCard(),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '1h', label: Text('1 Hour')),
                ButtonSegment(value: '24h', label: Text('24 Hours')),
                ButtonSegment(value: '7d', label: Text('7 Days')),
              ],
              selected: {_selectedTimeRange},
              onSelectionChanged: (Set<String> selection) {
                _updateTimeRange(selection.first);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Maximum',
                    _maxRate,
                    Icons.arrow_upward,
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildStatCard(
                    'Average',
                    _avgRate,
                    Icons.horizontal_rule,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatCard(
                    'Minimum',
                    _minRate,
                    Icons.arrow_downward,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildChart(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
