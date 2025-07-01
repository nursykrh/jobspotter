import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:job4/models/user_model.dart';
import 'package:job4/screens/admin/employer_details_screen.dart';

class EmployersTab extends StatelessWidget {
  const EmployersTab({super.key});

  Stream<List<UserModel>> _getEmployersByStatus(String status) {
    // Query both users and employers collections for comprehensive results
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'employer')
        .where('verificationStatus', isEqualTo: status)
        .snapshots()
        .asyncMap((snapshot) async {
          List<UserModel> employers = snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data()))
              .toList();
          
          // Also check employers collection for any missing data
          final employersSnapshot = await FirebaseFirestore.instance
              .collection('employers')
              .where('status', isEqualTo: status)
              .get();
          
          // Add employers that might not be in users collection
          for (final employerDoc in employersSnapshot.docs) {
            final employerData = employerDoc.data();
            final employerId = employerDoc.id;
            
            // Check if this employer is already in the list
            final exists = employers.any((emp) => emp.uid == employerId);
            if (!exists) {
              // Create a UserModel from employer data
              final employer = UserModel(
                uid: employerId,
                email: employerData['email'] ?? '',
                role: 'employer',
                verificationStatus: status,
                companyName: employerData['companyName'],
                phone: employerData['phone'],
                website: employerData['website'],
                industry: employerData['industry'],
                ssmNumber: employerData['ssmNumber'],
                companyAddress: employerData['companyAddress'],
                ssmDocumentUrl: employerData['ssmDocumentUrl'],
                createdAt: employerData['createdAt'] ?? Timestamp.now(),
                appliedJobs: 0,
                savedJobs: 0,
                interviews: 0,
              );
              employers.add(employer);
            }
          }
          
          // Sort all employers by createdAt timestamp (newest first)
          employers.sort((a, b) {
            return b.createdAt.compareTo(a.createdAt);
          });
          
          return employers;
        });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          flexibleSpace: const Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TabBar(
                labelColor: Color(0xFF4A90E2),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Color(0xFF4A90E2),
                tabs: [
                  Tab(text: 'Pending'),
                  Tab(text: 'Approved'),
                  Tab(text: 'Rejected'),
                ],
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildEmployerList(context, 'pending'),
            _buildEmployerList(context, 'approved'),
            _buildEmployerList(context, 'rejected'),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployerList(BuildContext context, String status) {
    return StreamBuilder<List<UserModel>>(
      stream: _getEmployersByStatus(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'No $status employers found.',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final employers = snapshot.data!;

        return ListView.builder(
          itemCount: employers.length,
          itemBuilder: (context, index) {
            final employer = employers[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                  child: const Icon(Icons.business, color: Color(0xFF4A90E2)),
                ),
                title: Text(employer.companyName ?? 'No Company Name'),
                subtitle: Text(employer.email),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmployerDetailsScreen(employer: employer),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
} 