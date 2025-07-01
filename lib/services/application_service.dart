import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class ApplicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Submit a new job application
  Future<void> applyForJob({
    required String jobId,
    required String jobseekerUid,
    required String jobseekerEmail,
    required String jobTitle,
    required String company,
    required String name,
    required String phone,
    required String experience,
    required String education,
    required String skills,
    required String coverLetter,
    required String employerEmail,
    required String location,
    required String salary,
    String? resumeUrl,
    String? coverLetterUrl,
  }) async {
    try {
      // Guna ID tetap: jobId_jobseekerEmail
      final fixedId = '${jobId}_$jobseekerEmail';
      final applicationData = {
        'jobId': jobId,
        'jobseekerUid': jobseekerUid,
        'jobseekerEmail': jobseekerEmail,
        'jobTitle': jobTitle,
        'company': company,
        'status': 'pending',
        'appliedAt': FieldValue.serverTimestamp(),
        'applicantName': name,
        'applicantPhone': phone,
        'experience': experience,
        'education': education,
        'skills': skills,
        'coverLetter': coverLetter,
        'employerEmail': employerEmail,
        'location': location,
        'salary': salary,
        if (resumeUrl != null) 'resumeUrl': resumeUrl,
        if (coverLetterUrl != null) 'coverLetterUrl': coverLetterUrl,
      };

      // Simpan ke jobApplications dengan ID tetap
      await _firestore.collection('jobApplications').doc(fixedId).set(applicationData);

      // Simpan ke subcollection user dengan ID yang sama
      try {
      await _firestore
        .collection('users')
        .doc(jobseekerEmail)
        .collection('applications')
        .doc(fixedId)
        .set(applicationData);
      } catch (e) {
        // Warning: Could not save to user subcollection
        // Continue execution even if subcollection save fails
      }

      // Increment user's appliedJobs count (create document if it doesn't exist)
      await _firestore.collection('users').doc(jobseekerEmail).set({
        'appliedJobs': FieldValue.increment(1),
        'email': jobseekerEmail,
        'role': 'jobseeker',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Hantar notifikasi ke employer
      await NotificationService.sendApplicationNotification(
        jobseekerEmail: employerEmail,
        jobTitle: jobTitle,
        company: company,
        applicationId: fixedId,
        type: 'new_application',
      );

      // Send confirmation notification to the jobseeker
      await NotificationService.sendJobStatusNotification(
        jobseekerEmail: jobseekerEmail,
        jobTitle: jobTitle,
        company: company,
        status: 'applied',
      );

      // Application submitted successfully
    } catch (e) {
      // Error submitting application
      // Error type and details available in e
      throw Exception('Failed to submit application: ${e.toString()}');
    }
  }

  // Get applications for a specific employer's jobs
  Future<List<Map<String, dynamic>>> getApplicationsForEmployer(String employerEmail) async {
    // Get all job IDs for this employer
    final jobsSnapshot = await _firestore
        .collection('jobs')
        .where('employerEmail', isEqualTo: employerEmail)
        .get();
    final jobIds = jobsSnapshot.docs.map((doc) => doc['id']).toList();

    if (jobIds.isEmpty) return [];

    // Get all applications for those jobs
    final appsSnapshot = await _firestore
        .collection('jobApplications')
        .where('jobId', whereIn: jobIds)
        .get();

    return appsSnapshot.docs.map((doc) {
      final data = doc.data();
      return {...data, 'id': doc.id};
    }).toList();
  }

  // Get all applications for a jobseeker
  Stream<QuerySnapshot> getApplicationsForJobseeker(String jobseekerEmail) {
    return _firestore
        .collection('jobApplications')
        .where('jobseekerEmail', isEqualTo: jobseekerEmail)
        .orderBy('appliedAt', descending: true)
        .snapshots();
  }

  // Update application status and send notification
  Future<void> updateApplicationStatus(String applicationId, String status) async {
    try {
      // Get the application data first
      DocumentSnapshot appDoc = await _firestore.collection('jobApplications').doc(applicationId).get();
      if (!appDoc.exists) {
        throw Exception('Application not found');
      }

      final appData = appDoc.data() as Map<String, dynamic>;
      final previousStatus = appData['status'];

      // Update in jobApplications collection
      await _firestore.collection('jobApplications').doc(applicationId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final userEmail = appData['applicantEmail'] ?? appData['jobseekerEmail'];
      
      if (userEmail != null && userEmail.isNotEmpty) {
        // Handle interview counter changes
        if ((status.toLowerCase() == 'interview' || status.toLowerCase() == 'accepted') && 
            previousStatus != 'interview' && previousStatus != 'accepted') {
          // Increment interview count if moving to interview/accepted status
          await _firestore.collection('users').doc(userEmail).update({
            'interviews': FieldValue.increment(1),
          });
        } else if ((previousStatus == 'interview' || previousStatus == 'accepted') && 
                   status.toLowerCase() != 'interview' && status.toLowerCase() != 'accepted') {
          // Decrement interview count if moving away from interview/accepted status
          await _firestore.collection('users').doc(userEmail).update({
            'interviews': FieldValue.increment(-1),
          });
        }

        // Update in user's applications subcollection
        try {
          await _firestore
            .collection('users')
            .doc(userEmail)
            .collection('applications')
            .doc(applicationId)
            .set({
              'status': status,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        } catch (e) {
          // Continue even if subcollection update fails
        }
      }

      await NotificationService.sendJobStatusNotification(
        jobseekerEmail: appData['applicantEmail'] ?? appData['jobseekerEmail'] ?? '',
        jobTitle: appData['jobTitle'] ?? '',
        company: appData['company'] ?? '',
        status: status,
      );

      // Application status updated successfully
    } catch (e) {
      throw Exception('Failed to update application status: $e');
    }
  }

  // Get a single application by ID
  Future<DocumentSnapshot> getApplicationById(String applicationId) {
    return _firestore.collection('jobApplications').doc(applicationId).get();
  }

  // Delete an application
  Future<void> deleteApplication(String applicationId) async {
    try {
      // Get the application data first to get user email
      DocumentSnapshot appDoc = await _firestore.collection('jobApplications').doc(applicationId).get();
      if (!appDoc.exists) {
        throw Exception('Application not found');
      }

      final appData = appDoc.data() as Map<String, dynamic>;
      final userEmail = appData['jobseekerEmail'];

      // Delete from main collection
      await _firestore.collection('jobApplications').doc(applicationId).delete();

      // Delete from user's subcollection if it exists
      if (userEmail != null && userEmail.isNotEmpty) {
        try {
          await _firestore
            .collection('users')
            .doc(userEmail)
            .collection('applications')
            .doc(applicationId)
            .delete();
        } catch (e) {
          // Continue even if subcollection delete fails
        }

        // Decrement user's appliedJobs count
        await _firestore.collection('users').doc(userEmail).update({
          'appliedJobs': FieldValue.increment(-1),
        });
      }
    } catch (e) {
      throw Exception('Failed to delete application: $e');
    }
  }

  Stream<QuerySnapshot> getUserApplications(String userEmail) {
    return _firestore
        .collection('jobApplications')
        .where('applicantEmail', isEqualTo: userEmail)
        .orderBy('appliedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getEmployerApplications(String employerEmail) {
    return _firestore
        .collection('jobApplications')
        .where('employerEmail', isEqualTo: employerEmail)
        .orderBy('appliedAt', descending: true)
        .snapshots();
  }
}