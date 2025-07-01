import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final Map<String, int> _stats = {
    'Total Users': 0,
    'Total Jobs': 0,
    'Active Applications': 0,
    'Employers': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // Load total users
      final usersCount = await FirebaseFirestore.instance
          .collection('users')
          .count()
          .get();
      
      // Load total jobs
      final jobsCount = await FirebaseFirestore.instance
          .collection('jobs')
          .count()
          .get();
      
      // Load active applications
      final applicationsCount = await FirebaseFirestore.instance
          .collection('applications')
          .where('status', isEqualTo: 'active')
          .count()
          .get();
      
      // Load employers
      final employersCount = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'employer')
          .count()
          .get();

      if (mounted) {
        setState(() {
          _stats['Total Users'] = usersCount.count ?? 0;
          _stats['Total Jobs'] = jobsCount.count ?? 0;
          _stats['Active Applications'] = applicationsCount.count ?? 0;
          _stats['Employers'] = employersCount.count ?? 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stats: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Grid
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: _stats.entries.map((entry) {
              return _buildStatCard(
                title: entry.key,
                value: entry.value.toString(),
                icon: _getIconForStat(entry.key),
                color: _getColorForStat(entry.key),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Charts Row
          Row(
            children: [
              // User Registration Chart
              Expanded(
                child: SizedBox(
                  height: 300,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'User Registrations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: 100,
                                barTouchData: const BarTouchData(enabled: false),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          ['Jan', 'Feb', 'Mar', 'Apr', 'May'][value.toInt()],
                                          style: const TextStyle(fontSize: 12),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          value.toInt().toString(),
                                          style: const TextStyle(fontSize: 12),
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                gridData: const FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                barGroups: [
                                  _makeBarGroup(0, 45),
                                  _makeBarGroup(1, 60),
                                  _makeBarGroup(2, 75),
                                  _makeBarGroup(3, 55),
                                  _makeBarGroup(4, 80),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Job Categories Chart
              Expanded(
                child: SizedBox(
                  height: 300,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Job Categories',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: [
                                  _makePieSection('IT', 30, Colors.blue),
                                  _makePieSection('Sales', 25, Colors.green),
                                  _makePieSection('Marketing', 20, Colors.orange),
                                  _makePieSection('Others', 25, Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForStat(String stat) {
    switch (stat) {
      case 'Total Users':
        return Icons.people;
      case 'Total Jobs':
        return Icons.work;
      case 'Active Applications':
        return Icons.assignment;
      case 'Employers':
        return Icons.business;
      default:
        return Icons.info;
    }
  }

  Color _getColorForStat(String stat) {
    switch (stat) {
      case 'Total Users':
        return Colors.blue;
      case 'Total Jobs':
        return Colors.green;
      case 'Active Applications':
        return Colors.orange;
      case 'Employers':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  BarChartGroupData _makeBarGroup(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: Colors.blue,
          width: 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }

  PieChartSectionData _makePieSection(String title, double value, Color color) {
    return PieChartSectionData(
      color: color,
      value: value,
      title: '$title\n${value.toInt()}%',
      radius: 100,
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
} 