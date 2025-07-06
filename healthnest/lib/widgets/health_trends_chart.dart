import 'package:flutter/cupertino.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../models/health_record.dart';

class HealthTrendsChart extends StatefulWidget {
  final List<HealthRecord> healthRecords;
  final String metricName;
  final String? unit;
  final Color? lineColor;
  final Color? fillColor;

  const HealthTrendsChart({
    super.key,
    required this.healthRecords,
    required this.metricName,
    this.unit,
    this.lineColor,
    this.fillColor,
  });

  @override
  State<HealthTrendsChart> createState() => _HealthTrendsChartState();
}

class _HealthTrendsChartState extends State<HealthTrendsChart> {
  late List<ChartData> chartData;
  late ZoomPanBehavior _zoomPanBehavior;
  late TrackballBehavior _trackballBehavior;

  @override
  void initState() {
    super.initState();
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableDoubleTapZooming: true,
    );
    _trackballBehavior = TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
    );
    _prepareChartData();
  }

  @override
  void didUpdateWidget(HealthTrendsChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.healthRecords != widget.healthRecords) {
      _prepareChartData();
    }
  }

  void _prepareChartData() {
    chartData = <ChartData>[];
    
    // Filter records for the specific metric
    final List<HealthRecord> metricRecords = widget.healthRecords
        .where((record) => record.recordType == 'lab_report' || record.recordType == 'vital_signs')
        .where((record) => _hasMetric(record, widget.metricName))
        .toList();

    // Sort by date
    metricRecords.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final record in metricRecords) {
      final double? value = _extractMetricValue(record, widget.metricName);
      if (value != null) {
        chartData.add(ChartData(
          record.createdAt,
          value,
          _formatDate(record.createdAt),
        ));
      }
    }
  }

  bool _hasMetric(HealthRecord record, String metricName) {
    if (record.data.containsKey('test_results')) {
      final Map<String, dynamic> testResults = record.data['test_results'];
      return testResults.containsKey(metricName.toLowerCase()) ||
             testResults.keys.any((key) => key.toLowerCase().contains(metricName.toLowerCase()));
    }
    
    if (record.data.containsKey('vitals')) {
      final Map<String, dynamic> vitals = record.data['vitals'];
      return vitals.containsKey(metricName.toLowerCase()) ||
             vitals.keys.any((key) => key.toLowerCase().contains(metricName.toLowerCase()));
    }
    
    return false;
  }

  double? _extractMetricValue(HealthRecord record, String metricName) {
    if (record.data.containsKey('test_results')) {
      final Map<String, dynamic> testResults = record.data['test_results'];
      
      // Try exact match first
      if (testResults.containsKey(metricName.toLowerCase())) {
        final dynamic result = testResults[metricName.toLowerCase()];
        if (result is Map && result.containsKey('value')) {
          return double.tryParse(result['value'].toString());
        }
        return double.tryParse(result.toString());
      }
      
      // Try partial match
      for (final entry in testResults.entries) {
        if (entry.key.toLowerCase().contains(metricName.toLowerCase())) {
          final dynamic result = entry.value;
          if (result is Map && result.containsKey('value')) {
            return double.tryParse(result['value'].toString());
          }
          return double.tryParse(result.toString());
        }
      }
    }
    
    if (record.data.containsKey('vitals')) {
      final Map<String, dynamic> vitals = record.data['vitals'];
      
      // Handle blood pressure specially
      if (metricName.toLowerCase().contains('blood pressure') || metricName.toLowerCase().contains('bp')) {
        if (vitals.containsKey('blood_pressure')) {
          final Map<String, dynamic> bp = vitals['blood_pressure'];
          if (bp.containsKey('systolic')) {
            return double.tryParse(bp['systolic'].toString());
          }
        }
      }
      
      // Try exact match
      if (vitals.containsKey(metricName.toLowerCase())) {
        final dynamic result = vitals[metricName.toLowerCase()];
        if (result is Map && result.containsKey('value')) {
          return double.tryParse(result['value'].toString());
        }
        return double.tryParse(result.toString());
      }
      
      // Try partial match
      for (final entry in vitals.entries) {
        if (entry.key.toLowerCase().contains(metricName.toLowerCase())) {
          final dynamic result = entry.value;
          if (result is Map && result.containsKey('value')) {
            return double.tryParse(result['value'].toString());
          }
          return double.tryParse(result.toString());
        }
      }
    }
    
    return null;
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (chartData.isEmpty) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: Text(
            'No data available for this metric',
            style: TextStyle(
              color: CupertinoColors.systemGrey,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.metricName}${widget.unit != null ? ' (${widget.unit})' : ''}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SfCartesianChart(
              primaryXAxis: DateTimeAxis(
                majorGridLines: const MajorGridLines(width: 0),
                dateFormat: DateFormat('MMM dd'),
                intervalType: DateTimeIntervalType.auto,
              ),
              primaryYAxis: NumericAxis(
                majorGridLines: const MajorGridLines(width: 0.5, color: CupertinoColors.systemGrey4),
                labelFormat: '{value}',
              ),
              series: <CartesianSeries>[
                AreaSeries<ChartData, DateTime>(
                  dataSource: chartData,
                  xValueMapper: (ChartData data, _) => data.x,
                  yValueMapper: (ChartData data, _) => data.y,
                  name: widget.metricName,
                  color: widget.fillColor ?? CupertinoColors.systemBlue.withValues(alpha: 0.3),
                  borderColor: widget.lineColor ?? CupertinoColors.systemBlue,
                  borderWidth: 2,
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: false,
                  ),
                ),
                LineSeries<ChartData, DateTime>(
                  dataSource: chartData,
                  xValueMapper: (ChartData data, _) => data.x,
                  yValueMapper: (ChartData data, _) => data.y,
                  name: widget.metricName,
                  color: widget.lineColor ?? CupertinoColors.systemBlue,
                  width: 3,
                  markerSettings: const MarkerSettings(
                    isVisible: true,
                    height: 6,
                    width: 6,
                  ),
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: false,
                  ),
                ),
              ],
              zoomPanBehavior: _zoomPanBehavior,
              trackballBehavior: _trackballBehavior,
              tooltipBehavior: TooltipBehavior(
                enable: true,
                format: '${widget.metricName}: point.y${widget.unit != null ? ' ${widget.unit}' : ''}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChartData {
  final DateTime x;
  final double y;
  final String dateString;

  ChartData(this.x, this.y, this.dateString);
}

class HealthMetricsSummary extends StatelessWidget {
  final List<HealthRecord> healthRecords;
  final List<String> metrics;

  const HealthMetricsSummary({
    super.key,
    required this.healthRecords,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Health Metrics Summary',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...metrics.map((metric) => _buildMetricCard(metric)),
      ],
    );
  }

  Widget _buildMetricCard(String metric) {
    final List<HealthRecord> metricRecords = healthRecords
        .where((record) => record.recordType == 'lab_report' || record.recordType == 'vital_signs')
        .where((record) => _hasMetric(record, metric))
        .toList();

    if (metricRecords.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get latest value
    metricRecords.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latestRecord = metricRecords.first;
    final double? latestValue = _extractMetricValue(latestRecord, metric);

    if (latestValue == null) {
      return const SizedBox.shrink();
    }

    // Calculate trend
    String trend = 'stable';
    Color trendColor = CupertinoColors.systemGrey;
    
    if (metricRecords.length > 1) {
      final previousRecord = metricRecords[1];
      final double? previousValue = _extractMetricValue(previousRecord, metric);
      
      if (previousValue != null) {
        final double change = latestValue - previousValue;
        final double changePercent = (change / previousValue) * 100;
        
        if (changePercent > 5) {
          trend = 'increasing';
          trendColor = CupertinoColors.systemRed;
        } else if (changePercent < -5) {
          trend = 'decreasing';
          trendColor = CupertinoColors.systemGreen;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.systemGrey4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Latest: $latestValue',
                  style: const TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: trendColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              trend,
              style: TextStyle(
                fontSize: 12,
                color: trendColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasMetric(HealthRecord record, String metricName) {
    if (record.data.containsKey('test_results')) {
      final Map<String, dynamic> testResults = record.data['test_results'];
      return testResults.containsKey(metricName.toLowerCase()) ||
             testResults.keys.any((key) => key.toLowerCase().contains(metricName.toLowerCase()));
    }
    
    if (record.data.containsKey('vitals')) {
      final Map<String, dynamic> vitals = record.data['vitals'];
      return vitals.containsKey(metricName.toLowerCase()) ||
             vitals.keys.any((key) => key.toLowerCase().contains(metricName.toLowerCase()));
    }
    
    return false;
  }

  double? _extractMetricValue(HealthRecord record, String metricName) {
    if (record.data.containsKey('test_results')) {
      final Map<String, dynamic> testResults = record.data['test_results'];
      
      if (testResults.containsKey(metricName.toLowerCase())) {
        final dynamic result = testResults[metricName.toLowerCase()];
        if (result is Map && result.containsKey('value')) {
          return double.tryParse(result['value'].toString());
        }
        return double.tryParse(result.toString());
      }
      
      for (final entry in testResults.entries) {
        if (entry.key.toLowerCase().contains(metricName.toLowerCase())) {
          final dynamic result = entry.value;
          if (result is Map && result.containsKey('value')) {
            return double.tryParse(result['value'].toString());
          }
          return double.tryParse(result.toString());
        }
      }
    }
    
    if (record.data.containsKey('vitals')) {
      final Map<String, dynamic> vitals = record.data['vitals'];
      
      if (vitals.containsKey(metricName.toLowerCase())) {
        final dynamic result = vitals[metricName.toLowerCase()];
        if (result is Map && result.containsKey('value')) {
          return double.tryParse(result['value'].toString());
        }
        return double.tryParse(result.toString());
      }
      
      for (final entry in vitals.entries) {
        if (entry.key.toLowerCase().contains(metricName.toLowerCase())) {
          final dynamic result = entry.value;
          if (result is Map && result.containsKey('value')) {
            return double.tryParse(result['value'].toString());
          }
          return double.tryParse(result.toString());
        }
      }
    }
    
    return null;
  }
} 