import 'package:flutter/material.dart';
import '../services/application_service.dart';

class EmployerApplicationsTab extends StatefulWidget {
  final String employerEmail;
  const EmployerApplicationsTab({required this.employerEmail, Key? key}) : super(key: key);

  @override
  State<EmployerApplicationsTab> createState() => _EmployerApplicationsTabState();
}

class _EmployerApplicationsTabState extends State<EmployerApplicationsTab> {
  late Future<List<Map<String, dynamic>>> _applicationsFuture;

  @override
  void initState() {
    super.initState();
    _refreshApplications();
  }

  void _refreshApplications() {
    setState(() {
      _applicationsFuture = ApplicationService().getApplicationsForEmployer(widget.employerEmail);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _applicationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final applications = snapshot.data ?? [];
        // Applications in UI: $applications
        if (applications.isEmpty) {
          return const Center(child: Text('No applications yet.'));
        }
        return ListView(
          children: applications.map((app) {
            return Card(
              child: ListTile(
                title: Text('Jobseeker: ${app['jobseekerEmail'] ?? app['email'] ?? ''}'),
                subtitle: Text('Job: ${app['jobTitle'] ?? ''}\nStatus: ${app['status'] ?? ''}'),
              ),
            );
          }).toList(),
        );
      },
    );
  }
} 