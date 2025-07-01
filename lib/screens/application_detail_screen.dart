import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ApplicationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> application;
  const ApplicationDetailScreen({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Application Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('Job Title: ${application['jobTitle'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 8),
            Text('Company: ${application['company'] ?? ''}'),
            const SizedBox(height: 8),
            Text('Status: ${application['status'] ?? ''}'),
            const SizedBox(height: 8),
            Text('Applied At: ${application['appliedAt']?.toString() ?? ''}'),
            const SizedBox(height: 16),
            const Text('Cover Letter:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(application['coverLetter'] ?? '-'),
            const SizedBox(height: 16),
            Text('Education: ${application['education'] ?? '-'}'),
            Text('Experience: ${application['experience'] ?? '-'}'),
            Text('Location: ${application['location'] ?? '-'}'),
            Text('Phone: ${application['phone'] ?? '-'}'),
            Text('Email: ${application['jobseekerEmail'] ?? application['email'] ?? '-'}'),
            if (application['resumeUrl'] != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('View Resume'),
                onPressed: () => launchUrl(Uri.parse(application['resumeUrl'])),
              ),
            if (application['coverLetterUrl'] != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('View Cover Letter'),
                onPressed: () => launchUrl(Uri.parse(application['coverLetterUrl'])),
              ),
            // Add more fields as needed
          ],
        ),
      ),
    );
  }
} 