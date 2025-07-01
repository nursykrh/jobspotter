import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get total counts for dashboard
  Future<Map<String, int>> getDashboardCounts() async {
    final users = await _firestore.collection('users').count().get();
    final jobs = await _firestore.collection('jobs').count().get();
    final employers = await _firestore.collection('employers').count().get();
    final applications = await _firestore.collection('applications').count().get();

    return {
      'users': users.count ?? 0,
      'jobs': jobs.count ?? 0,
      'employers': employers.count ?? 0,
      'applications': applications.count ?? 0,
    };
  }

  // Get job statistics by category
  Future<List<Map<String, dynamic>>> getJobsByCategory() async {
    final jobsSnapshot = await _firestore.collection('jobs').get();
    Map<String, int> categoryCount = {};

    for (var job in jobsSnapshot.docs) {
      final category = job.data()['category'] as String? ?? 'Other';
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
    }

    return categoryCount.entries
        .map((e) => {'category': e.key, 'count': e.value})
        .toList();
  }

  // Get application statistics by status
  Future<Map<String, int>> getApplicationsByStatus() async {
    final applicationsSnapshot = await _firestore.collection('applications').get();
    Map<String, int> statusCount = {
      'pending': 0,
      'accepted': 0,
      'rejected': 0,
      'withdrawn': 0,
    };

    for (var application in applicationsSnapshot.docs) {
      final status = application.data()['status'] as String? ?? 'pending';
      statusCount[status] = (statusCount[status] ?? 0) + 1;
    }

    return statusCount;
  }

  // Get user registration trend (last 7 days)
  Future<List<Map<String, dynamic>>> getUserRegistrationTrend() async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final usersSnapshot = await _firestore
        .collection('users')
        .where('createdAt', isGreaterThanOrEqualTo: sevenDaysAgo)
        .orderBy('createdAt')
        .get();

    Map<String, int> dailyCount = {};
    
    // Initialize all days with 0
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('MM/dd').format(date);
      dailyCount[dateStr] = 0;
    }

    // Count registrations per day
    for (var user in usersSnapshot.docs) {
      final createdAt = (user.data()['createdAt'] as Timestamp).toDate();
      final dateStr = DateFormat('MM/dd').format(createdAt);
      dailyCount[dateStr] = (dailyCount[dateStr] ?? 0) + 1;
    }

    return dailyCount.entries
        .map((e) => {'date': e.key, 'count': e.value})
        .toList()
        .reversed
        .toList();
  }

  // Get employer approval rate
  Future<Map<String, dynamic>> getEmployerApprovalRate() async {
    final employersSnapshot = await _firestore.collection('employers').get();
    int approved = 0;
    int rejected = 0;
    int pending = 0;

    for (var employer in employersSnapshot.docs) {
      final status = employer.data()['status'] as String? ?? 'pending';
      switch (status) {
        case 'approved':
          approved++;
          break;
        case 'rejected':
          rejected++;
          break;
        case 'pending':
          pending++;
          break;
      }
    }

    final total = approved + rejected + pending;
    return {
      'approved': approved,
      'rejected': rejected,
      'pending': pending,
      'total': total,
      'approvalRate': total > 0 ? (approved / total * 100).toStringAsFixed(1) : '0',
    };
  }

  // Get recent activities
  Future<List<Map<String, dynamic>>> getRecentActivities() async {
    final now = DateTime.now();
    final oneDayAgo = now.subtract(const Duration(days: 1));

    // Get recent job postings
    final recentJobs = await _firestore
        .collection('jobs')
        .where('createdAt', isGreaterThanOrEqualTo: oneDayAgo)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();

    // Get recent applications
    final recentApplications = await _firestore
        .collection('applications')
        .where('createdAt', isGreaterThanOrEqualTo: oneDayAgo)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();

    List<Map<String, dynamic>> activities = [];

    // Add job activities
    for (var job in recentJobs.docs) {
      activities.add({
        'type': 'job',
        'title': job.data()['title'] ?? 'New Job Posted',
        'timestamp': job.data()['createdAt'] as Timestamp,
        'description': 'New job posted by ${job.data()['employerName'] ?? 'an employer'}',
      });
    }

    // Add application activities
    for (var application in recentApplications.docs) {
      activities.add({
        'type': 'application',
        'title': 'New Application',
        'timestamp': application.data()['createdAt'] as Timestamp,
        'description': 'New application submitted for ${application.data()['jobTitle'] ?? 'a job'}',
      });
    }

    // Sort by timestamp
    activities.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    return activities.take(10).toList();
  }

  Future<Map<String, dynamic>> getEmployerStatistics(String employerId) async {
    try {
      // Get all jobs posted by this employer
      final jobsQuery = await _firestore
          .collection('jobs')
          .where('employerId', isEqualTo: employerId)
          .get();

      final List<String> jobIds = jobsQuery.docs.map((doc) => doc.id).toList();
      
      // Get weekly applications data
      final now = DateTime.now();
      final fourWeeksAgo = now.subtract(const Duration(days: 28));
      
      final applicationsQuery = await _firestore
          .collection('jobApplications')
          .where('jobId', whereIn: jobIds.isEmpty ? [''] : jobIds)
          .where('appliedAt', isGreaterThanOrEqualTo: fourWeeksAgo)
          .orderBy('appliedAt', descending: false)
          .get();

      // Group applications by week
      final List<int> weeklyApplications = List.filled(4, 0);
      final List<double> weeklyResponseRates = List.filled(4, 0);
      
      for (var doc in applicationsQuery.docs) {
        final appliedAt = (doc.data()['appliedAt'] as Timestamp).toDate();
        final weekIndex = now.difference(appliedAt).inDays ~/ 7;
        if (weekIndex < 4) {
          weeklyApplications[weekIndex]++;
          if (doc.data()['status'] != 'pending') {
            weeklyResponseRates[weekIndex]++;
          }
        }
      }

      // Calculate response rates
      for (var i = 0; i < 4; i++) {
        if (weeklyApplications[i] > 0) {
          weeklyResponseRates[i] = (weeklyResponseRates[i] / weeklyApplications[i]) * 100;
        }
      }

      // Calculate other statistics
      final int totalJobs = jobsQuery.docs.length;
      final int totalApplications = applicationsQuery.docs.length;
      
      // Calculate accepted applications
      final acceptedApplications = applicationsQuery.docs
          .where((doc) => doc.data()['status'] == 'accepted')
          .length;

      // Calculate response rate
      final respondedApplications = applicationsQuery.docs
          .where((doc) => doc.data()['status'] != 'pending')
          .length;

      final double responseRate = totalApplications > 0
          ? (respondedApplications / totalApplications) * 100
          : 0;

      // Calculate job success rate
      final double successRate = totalApplications > 0
          ? (acceptedApplications / totalApplications) * 100
          : 0;

      // Get last month's jobs for growth calculation
      final lastMonthStart = DateTime.now().subtract(const Duration(days: 60));
      final lastMonthEnd = DateTime.now().subtract(const Duration(days: 30));
      
      final lastMonthJobs = await _firestore
          .collection('jobs')
          .where('employerId', isEqualTo: employerId)
          .where('createdAt', isGreaterThanOrEqualTo: lastMonthStart)
          .where('createdAt', isLessThan: lastMonthEnd)
          .get();

      final thisMonthJobs = await _firestore
          .collection('jobs')
          .where('employerId', isEqualTo: employerId)
          .where('createdAt', isGreaterThanOrEqualTo: lastMonthEnd)
          .get();

      // Calculate job posting growth
      final double growth = lastMonthJobs.docs.isNotEmpty
          ? ((thisMonthJobs.docs.length - lastMonthJobs.docs.length) /
              lastMonthJobs.docs.length) *
              100
          : 0;

      return {
        'totalJobs': totalJobs,
        'activeJobs': jobsQuery.docs.where((doc) => doc.data()['status'] == 'active').length,
        'totalApplications': totalApplications,
        'successRate': successRate,
        'responseRate': responseRate,
        'growth': growth,
        'weeklyApplications': weeklyApplications,
        'weeklyResponseRates': weeklyResponseRates,
      };
    } catch (e) {
      return {
        'totalJobs': 0,
        'activeJobs': 0,
        'totalApplications': 0,
        'successRate': 0,
        'responseRate': 0,
        'growth': 0,
        'weeklyApplications': List.filled(4, 0),
        'weeklyResponseRates': List.filled(4, 0),
      };
    }
  }
}