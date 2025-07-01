import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';

class EmployerApplicationsScreen extends StatelessWidget {
  const EmployerApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userEmail = Provider.of<AuthProvider>(context, listen: false).user?.email ?? '';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Applications', style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF6C63FF)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobApplications')
            .where('employerEmail', isEqualTo: userEmail)
            .orderBy('appliedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final applications = snapshot.data!.docs;
          
          if (applications.isEmpty) {
            return const Center(
              child: Text(
                'No applications yet',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: applications.length,
            itemBuilder: (context, index) {
              final app = applications[index].data() as Map<String, dynamic>;
              final applicationId = applications[index].id;
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app['jobTitle'] ?? 'No Title',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Applicant: ${app['applicantEmail'] ?? 'Unknown'}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          _buildStatusChip(app['status'] ?? 'pending'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Cover Letter:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(app['coverLetter'] ?? 'No cover letter provided'),
                      const SizedBox(height: 16),
                      if (app['status'] == 'pending') ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _updateApplicationStatus(
                                context,
                                applicationId,
                                app['applicantEmail'],
                                'rejected',
                              ),
                              child: const Text(
                                'Reject',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _updateApplicationStatus(
                                context,
                                applicationId,
                                app['applicantEmail'],
                                'accepted',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C63FF),
                              ),
                              child: const Text('Accept'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'accepted':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _updateApplicationStatus(
    BuildContext context,
    String applicationId,
    String applicantEmail,
    String newStatus,
  ) async {
    try {
      // Get application data for notification
      final appDoc = await FirebaseFirestore.instance
          .collection('jobApplications')
          .doc(applicationId)
          .get();
      final appData = appDoc.data();
      final jobTitle = appData?['jobTitle'] ?? '';
      final company = appData?['company'] ?? '';

      // Update in jobApplications collection
      await FirebaseFirestore.instance
          .collection('jobApplications')
          .doc(applicationId)
          .update({'status': newStatus});

      // Send notification to jobseeker
      await NotificationService.sendJobStatusNotification(
        jobseekerEmail: applicantEmail,
        jobTitle: jobTitle,
        company: company,
        status: newStatus,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Application $newStatus successfully'),
            backgroundColor: newStatus == 'accepted' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update application status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 