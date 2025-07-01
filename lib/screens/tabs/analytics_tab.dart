import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:job4/services/analytics_service.dart';


class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final AnalyticsService _analyticsService = AnalyticsService();
  late Future<List<Map<String, dynamic>>> _monthlyRegistrationsFuture;
  late Future<List<Map<String, dynamic>>> _monthlyJobsFuture;

  @override
  void initState() {
    super.initState();
    _monthlyRegistrationsFuture = _analyticsService.getMonthlyRegistrations();
    _monthlyJobsFuture = _analyticsService.getMonthlyJobPostingTrend();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false, // No back button
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChartCard(
              title: 'Monthly User Registrations',
              future: _monthlyRegistrationsFuture,
              chartBuilder: (data) => _buildBarChart(
                data: data,
                barColor: Colors.deepPurple,
                getBottomTitle: (value, data) {
                  if (value.toInt() < data.length) {
                    final parts =
                        (data[value.toInt()]['month'] as String).split(' ');
                    return parts.isNotEmpty ? parts[0] : '';
                  }
                  return '';
                },
                getTooltipItem: (group, groupIndex, rod, rodIndex, data) {
                  final month = data[groupIndex]['month'] as String;
                  final count = data[groupIndex]['count'] as int;
                  return BarTooltipItem(
                    '$month\n',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text: count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            _buildChartCard(
              title: 'Monthly Job Postings',
              future: _monthlyJobsFuture,
              chartBuilder: (data) => _buildBarChart(
                data: data,
                barColor: Colors.amber.shade700,
                getBottomTitle: (value, data) {
                  if (value.toInt() < data.length) {
                    final parts =
                        (data[value.toInt()]['month'] as String).split(' ');
                    return parts.isNotEmpty ? parts[0] : '';
                  }
                  return '';
                },
                getTooltipItem: (group, groupIndex, rod, rodIndex, data) {
                  final month = data[groupIndex]['month'] as String;
                  final count = data[groupIndex]['count'] as int;
                  return BarTooltipItem(
                    '$month\n',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text: 'Jobs: $count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required Future<List<Map<String, dynamic>>> future,
    required Widget Function(List<Map<String, dynamic>>) chartBuilder,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: Text('No data available')),
                  );
                }
                return SizedBox(
                    height: 220, child: chartBuilder(snapshot.data!));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart({
    required List<Map<String, dynamic>> data,
    required String Function(double, List<Map<String, dynamic>>) getBottomTitle,
    required BarTooltipItem Function(BarChartGroupData, int, BarChartRodData,
            int, List<Map<String, dynamic>>)
        getTooltipItem,
    required Color barColor,
  }) {
    final double maxVal = data.fold(
        0,
        (max, e) =>
            (e['count'] as int) > max ? (e['count'] as int).toDouble() : max);

    final double interval = maxVal > 0 ? (maxVal / 5).ceilToDouble() : 2.0;
    final double maxY = maxVal > 0 ? interval * 5 : 10.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.black87,
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                getTooltipItem(group, groupIndex, rod, rodIndex, data),
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(value.toInt().toString(),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final text = getBottomTitle(value, data);
                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    text,
                    style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey.shade300, strokeWidth: 1);
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          data.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: (data[i]['count'] as int).toDouble(),
                color: barColor,
                width: 22,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}