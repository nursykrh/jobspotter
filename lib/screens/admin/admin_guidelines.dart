import 'package:flutter/material.dart';

class AdminGuidelines extends StatelessWidget {
  const AdminGuidelines({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Guidelines'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGuidelineSection(
              'User Management',
              'Guidelines for managing user accounts:',
              [
                'Review and approve new user registrations',
                'Monitor user activities and reports',
                'Handle user account issues and support requests',
                'Maintain user data privacy and security',
              ],
            ),
            const SizedBox(height: 24),
            _buildGuidelineSection(
              'Job Postings',
              'Guidelines for managing job listings:',
              [
                'Review and verify new job postings',
                'Ensure job descriptions meet community standards',
                'Monitor and remove inappropriate content',
                'Update job categories as needed',
              ],
            ),
            const SizedBox(height: 24),
            _buildGuidelineSection(
              'Platform Maintenance',
              'Guidelines for system maintenance:',
              [
                'Monitor system performance and uptime',
                'Review and analyze platform analytics',
                'Coordinate with technical team for updates',
                'Maintain backup and recovery procedures',
              ],
            ),
            const SizedBox(height: 24),
            _buildGuidelineSection(
              'Communication',
              'Guidelines for communication:',
              [
                'Respond to user inquiries promptly',
                'Send important announcements and updates',
                'Maintain professional communication standards',
                'Document all major decisions and changes',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidelineSection(String title, String subtitle, List<String> points) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ...points.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 20,
                  color: Color(0xFF4CAF50),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    point,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
}