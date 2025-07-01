import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_stats_service.dart';
import '../../services/application_service.dart';

class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    return DefaultTabController(
      length: 2,
      initialIndex: 1, // Start with "Your Applications" tab to match profile "Applied" count
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activity', style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF6C63FF)),
          bottom: const TabBar(
            labelColor: Color(0xFF6C63FF),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF6C63FF),
            tabs: [
              Tab(text: 'Saved Jobs'),
              Tab(text: 'Your Applications'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            user != null ? SavedJobsTab(userId: user.uid) : const Center(child: Text('Please log in to see saved jobs.')),
            user != null ? MyApplicationsTab(userEmail: user.email ?? '') : const Center(child: Text('Please log in to see your applications.')),
          ],
        ),
      ),
    );
  }
}

class SavedJobsTab extends StatelessWidget {
  final String userId;
  const SavedJobsTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('savedJobs')
        .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final savedJobs = snapshot.data!.docs;
        if (savedJobs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_border, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text('No saved jobs yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: savedJobs.length,
          itemBuilder: (context, index) {
            final job = savedJobs[index].data() as Map<String, dynamic>;
            final jobId = savedJobs[index].id;
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.work, color: Color(0xFF6C63FF), size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job['title'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            job['company'] ?? '',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Remove from Saved',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Remove Saved Job'),
                            content: const Text('Are you sure you want to remove this job from your saved list?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            await UserStatsService.unsaveJob(userId, jobId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Job removed from saved'), backgroundColor: Colors.red),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error removing job: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class MyApplicationsTab extends StatelessWidget {
  final String userEmail;
  const MyApplicationsTab({super.key, required this.userEmail});

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      case 'interview':
        return 'Interview';
      default:
        return 'Pending';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'interview':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobApplications')
          .where('jobseekerEmail', isEqualTo: userEmail)
          .orderBy('appliedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: \n${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final applications = snapshot.data!.docs;
        if (applications.isEmpty) return const Center(child: Text('No applications yet'));
        return ListView.builder(
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final app = applications[index].data() as Map<String, dynamic>;
            final appId = applications[index].id;
            return GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(app['jobTitle'] ?? 'Application Overview'),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Company: ${app['company'] ?? ''}'),
                          Text('Status: ${_getStatusLabel(app['status'])}'),
                          Text(
                            'Applied: ${app['appliedAt'] != null && app['appliedAt'] is Timestamp ? (app['appliedAt'] as Timestamp).toDate().toString().substring(0, 10) : ''}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          const Text('Cover Letter:'),
                          Text(app['coverLetter'] ?? '-'),
                          const SizedBox(height: 8),
                          Text('Education: ${app['education'] ?? '-'}'),
                          Text('Experience: ${app['experience'] ?? '-'}'),
                          Text('Location: ${app['location'] ?? '-'}'),
                          Text('Phone: ${app['applicantPhone'] ?? app['phone'] ?? '-'}'),
                          Text('Email: ${app['jobseekerEmail'] ?? app['email'] ?? '-'}'),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              child: Card(
                color: const Color(0xFFF6F2FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.work_outline, color: Color(0xFF6C63FF), size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(app['jobTitle'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(app['company'] ?? '', style: const TextStyle(color: Colors.black54)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  'Applied: ${app['appliedAt'] != null && app['appliedAt'] is Timestamp ? (app['appliedAt'] as Timestamp).toDate().toString().substring(0, 10) : ''}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(app['status']).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getStatusLabel(app['status']),
                              style: TextStyle(
                                color: _getStatusColor(app['status']),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'delete') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                      title: const Text('Delete Application'),
                                      content: const Text('Are you sure you want to delete this application? This will also update your applied jobs count.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    try {
                                      await ApplicationService().deleteApplication(appId);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Application deleted successfully'), backgroundColor: Colors.green),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error deleting application: $e'), backgroundColor: Colors.red),
                                        );
                                      }
                                    }
                                  }
                              } else if (value == 'edit') {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    final TextEditingController coverLetterController = TextEditingController(text: app['coverLetter'] ?? '');
                                    return AlertDialog(
                                      title: const Text('Edit Application'),
                                      content: TextField(
                                        controller: coverLetterController,
                                        maxLines: 5,
                                        decoration: const InputDecoration(
                                          labelText: 'Cover Letter',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                        TextButton(
                                          onPressed: () async {
                                            try {
                                              await FirebaseFirestore.instance
                                                  .collection('jobApplications')
                                                  .doc(appId)
                                                  .update({'coverLetter': coverLetterController.text});
                                              if (context.mounted) {
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Application updated'), backgroundColor: Colors.green),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Error updating application: $e'), backgroundColor: Colors.red),
                                                );
                                              }
                                            }
                                          },
                                          child: const Text('Update'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Color(0xFF6C63FF)), SizedBox(width: 8), Text('Edit')],)),
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Delete')],)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}