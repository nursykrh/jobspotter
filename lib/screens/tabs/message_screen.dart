import 'package:flutter/material.dart';

class MessageScreen extends StatelessWidget {
  final Map<String, dynamic> job;
  const MessageScreen({Key? key, required this.job}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Employer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat with employer for:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(job['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(job['company'] ?? '', style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 24),
            const Expanded(
              child: Center(
                child: Text('Chat feature coming soon!', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 