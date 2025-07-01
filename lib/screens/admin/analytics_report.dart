import 'package:flutter/material.dart';
import '../report_view_screen.dart';

class AnalyticsReport extends StatefulWidget {
  const AnalyticsReport({super.key});

  @override
  State<AnalyticsReport> createState() => _AnalyticsReportState();
}

class _AnalyticsReportState extends State<AnalyticsReport> {
  String _selectedPeriod = 'Last 7 Days';
  final List<String> _timePeriods = [
    'Last 7 Days',
    'Last 14 Days',
    'Last 30 Days',
    'Last 3 Months',
    'Last 6 Months',
    'Last Year'
  ];

  void _showTimePeriodPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _timePeriods.map((period) => ListTile(
            title: Text(period),
            trailing: period == _selectedPeriod 
              ? const Icon(Icons.check, color: Colors.blue)
              : null,
            onTap: () {
              setState(() => _selectedPeriod = period);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _generateReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportViewScreen(
          reportType: 'Analytics Report',
          timePeriod: _selectedPeriod,
        ),
      ),
    );
  }

  Widget _buildReportItem({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 20,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Analytics Report',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.normal,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Analytics Report Title Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.bar_chart,
                            color: Colors.blue[400],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Analytics Report',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'View detailed job analytics and statistics',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Time Period Selector
                  InkWell(
                    onTap: _showTimePeriodPicker,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedPeriod,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Report Contents
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Report Contents',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildReportItem(
                    icon: Icons.work_outline,
                    iconColor: Colors.blue[400]!,
                    backgroundColor: Colors.blue[50]!,
                    title: 'Job Listings',
                    subtitle: 'Total jobs posted and their status',
                  ),
                  const SizedBox(height: 12),
                  _buildReportItem(
                    icon: Icons.description_outlined,
                    iconColor: Colors.green[400]!,
                    backgroundColor: Colors.green[50]!,
                    title: 'Applications',
                    subtitle: 'Job application analytics',
                  ),
                  const SizedBox(height: 12),
                  _buildReportItem(
                    icon: Icons.people_outline,
                    iconColor: Colors.orange[400]!,
                    backgroundColor: Colors.orange[50]!,
                    title: 'User Statistics',
                    subtitle: 'Employer and job seeker data',
                  ),
                  const SizedBox(height: 12),
                  _buildReportItem(
                    icon: Icons.analytics_outlined,
                    iconColor: Colors.purple[400]!,
                    backgroundColor: Colors.purple[50]!,
                    title: 'Job Categories',
                    subtitle: 'Most popular job categories',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _generateReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A237E), // Deep indigo color
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: const Text(
            'Generate Report',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}