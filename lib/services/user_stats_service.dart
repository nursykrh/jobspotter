import 'package:cloud_firestore/cloud_firestore.dart';

class UserStatsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save a job and increment counter
  static Future<void> saveJob(String userId, String jobId, Map<String, dynamic> jobData) async {
    try {
      // Add to saved jobs subcollection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedJobs')
          .doc(jobId)
          .set(jobData);

      // Increment saved jobs counter
      await _firestore.collection('users').doc(userId).update({
        'savedJobs': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Failed to save job: $e');
    }
  }

  // Unsave a job and decrement counter
  static Future<void> unsaveJob(String userId, String jobId) async {
    try {
      // Remove from saved jobs subcollection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedJobs')
          .doc(jobId)
          .delete();

      // Decrement saved jobs counter
      await _firestore.collection('users').doc(userId).update({
        'savedJobs': FieldValue.increment(-1),
      });
    } catch (e) {
      throw Exception('Failed to unsave job: $e');
    }
  }

  // Recalculate and update all user statistics
  static Future<void> recalculateUserStats(String userEmail) async {
    try {
      // Get the user document first to get the UID
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();
      
      if (userQuery.docs.isEmpty) {
        throw Exception('User not found with email: $userEmail');
      }
      
      final userId = userQuery.docs.first.id;

      // Count applied jobs
      final appliedJobsQuery = await _firestore
          .collection('jobApplications')
          .where('jobseekerEmail', isEqualTo: userEmail)
          .get();
      final appliedJobsCount = appliedJobsQuery.docs.length;

      // Count saved jobs
      final savedJobsQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedJobs')
          .get();
      final savedJobsCount = savedJobsQuery.docs.length;

      // Count interviews (accepted or interview status)
      final interviewsQuery = await _firestore
          .collection('jobApplications')
          .where('jobseekerEmail', isEqualTo: userEmail)
          .where('status', whereIn: ['interview', 'accepted'])
          .get();
      final interviewsCount = interviewsQuery.docs.length;

      // Update user statistics
      await _firestore.collection('users').doc(userId).update({
        'appliedJobs': appliedJobsCount,
        'savedJobs': savedJobsCount,
        'interviews': interviewsCount,
      });
    } catch (e) {
      throw Exception('Failed to recalculate user stats: $e');
    }
  }

  // Get current user statistics
  static Future<Map<String, int>> getUserStats(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        return {
          'appliedJobs': data['appliedJobs'] ?? 0,
          'savedJobs': data['savedJobs'] ?? 0,
          'interviews': data['interviews'] ?? 0,
        };
      }
      return {'appliedJobs': 0, 'savedJobs': 0, 'interviews': 0};
    } catch (e) {
      throw Exception('Failed to get user stats: $e');
    }
  }

  // Ensure user stats exist (for migration/initialization)
  static Future<void> ensureUserStatsExist(String userId, String email) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'email': email,
        'appliedJobs': 0,
        'savedJobs': 0,
        'interviews': 0,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to ensure user stats exist: $e');
    }
  }
} 