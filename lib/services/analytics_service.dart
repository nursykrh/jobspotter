import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user growth statistics
  Future<Map<String, dynamic>> getUserGrowthStats() async {
    try {
      final now = DateTime.now();
      final lastMonth = now.subtract(const Duration(days: 30));

      final currentUsersCount = await _firestore.collection('users').count().get();
      final lastMonthQuery = await _firestore
          .collection('users')
          .where('createdAt', isLessThan: lastMonth)
          .count()
          .get();

      final currentCount = currentUsersCount.count ?? 0;
      final lastMonthCount = lastMonthQuery.count ?? 0;
      
      final growth = lastMonthCount == 0 
          ? 100 
          : ((currentCount - lastMonthCount) / lastMonthCount * 100);

      return {
        'growth': growth.toStringAsFixed(1),
        'total': currentCount,
      };
    } catch (e) {
      return {'growth': '0', 'total': 0};
    }
  }

  // Get job success rate
  Future<double> getJobSuccessRate() async {
    try {
      final totalApplications = await _firestore
          .collection('applications')
          .count()
          .get();
      
      final acceptedApplications = await _firestore
          .collection('applications')
          .where('status', isEqualTo: 'accepted')
          .count()
          .get();

      if (totalApplications.count == 0) return 0;
      return (acceptedApplications.count ?? 0) / (totalApplications.count ?? 1) * 100;
    } catch (e) {
      return 0;
    }
  }

  // Get active users in last 30 days
  Future<int> getActiveUsersCount() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final activeUsers = await _firestore
          .collection('users')
          .where('lastActive', isGreaterThan: thirtyDaysAgo)
          .count()
          .get();

      return activeUsers.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Get employer response rate
  Future<double> getEmployerResponseRate() async {
    try {
      final totalApplications = await _firestore
          .collection('applications')
          .count()
          .get();
      
      final respondedApplications = await _firestore
          .collection('applications')
          .where('employerResponded', isEqualTo: true)
          .count()
          .get();

      if (totalApplications.count == 0) return 0;
      return (respondedApplications.count ?? 0) / (totalApplications.count ?? 1) * 100;
    } catch (e) {
      return 0;
    }
  }

  // Get monthly user registrations for the last 6 months
  Future<List<Map<String, dynamic>>> getMonthlyRegistrations() async {
    try {
      final now = DateTime.now();
      final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);

      final usersSnapshot = await _firestore
          .collection('users')
          .where('createdAt', isGreaterThan: sixMonthsAgo)
          .orderBy('createdAt')
          .get();

      // Create a map to store counts by month
      final monthlyData = <String, int>{};
      
      // Initialize all months with 0
      for (var i = 0; i < 6; i++) {
        final month = DateTime(now.year, now.month - i, 1);
        final monthKey = DateFormat('MMM yyyy').format(month);
        monthlyData[monthKey] = 0;
      }

      // Count registrations by month
      for (var doc in usersSnapshot.docs) {
        final createdAt = (doc.data()['createdAt'] as Timestamp).toDate();
        final monthKey = DateFormat('MMM yyyy').format(createdAt);
        monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + 1;
      }

      // Convert to list of maps for the chart
      return monthlyData.entries.map((e) => {
        'month': e.key,
        'count': e.value,
      }).toList().reversed.toList();
    } catch (e) {
      return [];
    }
  }

  // Get job categories distribution
  Future<List<Map<String, dynamic>>> getJobCategoriesDistribution() async {
    try {
      final jobsSnapshot = await _firestore.collection('jobs').get();
      final categoryCounts = <String, int>{};

      for (var doc in jobsSnapshot.docs) {
        final category = doc.data()['category'] as String? ?? 'Other';
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }

      return categoryCounts.entries.map((e) => {
        'category': e.key,
        'count': e.value,
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Get user registration trend for the last 7 days
  Future<List<Map<String, dynamic>>> getWeeklyUserRegistrationTrend() async {
    try {
      final dailyData = <String, int>{};
      final now = DateTime.now();
      
      // Initialize the last 7 days with 0 count
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final dayKey = DateFormat('yyyy-MM-dd').format(day);
        dailyData[dayKey] = 0;
      }

      // Get user data created in the last 7 days
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final usersSnapshot = await _firestore
          .collection('users')
          .where('createdAt', isGreaterThanOrEqualTo: sevenDaysAgo)
          .get();
      
      // Populate with real data from Firestore
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        // Check if 'createdAt' field exists and is a Timestamp
        if (data.containsKey('createdAt') && data['createdAt'] is Timestamp) {
          final createdAt = (data['createdAt'] as Timestamp).toDate();
          final dayKey = DateFormat('yyyy-MM-dd').format(createdAt);
          if (dailyData.containsKey(dayKey)) {
            dailyData[dayKey] = dailyData[dayKey]! + 1;
          }
        }
      }

      // Convert to a list of maps sorted by date for the chart
      final sortedKeys = dailyData.keys.toList()..sort();
      return sortedKeys
          .map((key) => {
                'day': DateFormat('E').format(DateFormat('yyyy-MM-dd').parse(key)), // 'Mon', 'Tue'
                'count': dailyData[key]!,
              })
          .toList();

    } catch (e) {
      // If the query fails (e.g., missing index), return an empty list.
      return [];
    }
  }

  // Get job posting trend for the last 7 days
  Future<List<Map<String, dynamic>>> getWeeklyJobPostingTrend() async {
    try {
      final dailyData = <String, int>{};
      final now = DateTime.now();

      // Initialize the last 7 days with 0 count
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final dayKey = DateFormat('yyyy-MM-dd').format(day);
        dailyData[dayKey] = 0;
      }

      // Get jobs posted in the last 7 days
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final jobsSnapshot = await _firestore
          .collection('jobs')
          .where('postedDate', isGreaterThanOrEqualTo: sevenDaysAgo.toIso8601String())
          .get();

      // Populate with real data from Firestore
      for (var doc in jobsSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('postedDate') && data['postedDate'] != null) {
          final dynamic postedDateValue = data['postedDate'];
          final DateTime postedDate;

          if (postedDateValue is Timestamp) {
            postedDate = postedDateValue.toDate();
          } else if (postedDateValue is String) {
            try {
              postedDate = DateTime.parse(postedDateValue);
            } catch (e) {
              continue; // Skip if parsing fails
            }
          } else {
            continue; // Skip if it's neither Timestamp nor String
          }

          final dayKey = DateFormat('yyyy-MM-dd').format(postedDate);
          if (dailyData.containsKey(dayKey)) {
            dailyData[dayKey] = dailyData[dayKey]! + 1;
          }
        }
      }

      // Convert to a list of maps sorted by date for the chart
      final sortedKeys = dailyData.keys.toList()..sort();
      return sortedKeys
          .map((key) => {
                'day': DateFormat('E').format(DateFormat('yyyy-MM-dd').parse(key)),
                'count': dailyData[key]!,
              })
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Get monthly job posting trend for the last 6 months
  Future<List<Map<String, dynamic>>> getMonthlyJobPostingTrend() async {
    try {
      final now = DateTime.now();
      final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);
      final monthlyData = <String, int>{};

      // Initialize all months with 0
      for (var i = 0; i < 6; i++) {
        final month = DateTime(now.year, now.month - i, 1);
        final monthKey = DateFormat('MMM yyyy').format(month);
        monthlyData[monthKey] = 0;
      }

      // Get jobs posted in the last 6 months
      final jobsSnapshot = await _firestore
          .collection('jobs')
          .where('postedDate', isGreaterThanOrEqualTo: sixMonthsAgo.toIso8601String())
          .get();

      // Count postings by month
      for (var doc in jobsSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('postedDate') && data['postedDate'] != null) {
          final dynamic postedDateValue = data['postedDate'];
          final DateTime postedDate;

          if (postedDateValue is Timestamp) {
            postedDate = postedDateValue.toDate();
          } else if (postedDateValue is String) {
            try {
              postedDate = DateTime.parse(postedDateValue);
            } catch (e) {
              continue; // Skip if parsing fails
            }
          } else {
            continue; // Skip if it's neither Timestamp nor String
          }

          final monthKey = DateFormat('MMM yyyy').format(postedDate);
          if (monthlyData.containsKey(monthKey)) {
            monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + 1;
          }
        }
      }

      // Convert to a list of maps, sorted by month
      final sortedEntries = monthlyData.entries.toList()
        ..sort((a, b) {
          final aDate = DateFormat('MMM yyyy').parse(a.key);
          final bDate = DateFormat('MMM yyyy').parse(b.key);
          return aDate.compareTo(bDate);
        });

      return sortedEntries
          .map((e) => {
                'month': e.key,
                'count': e.value,
              })
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Get key dashboard metrics
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      // 1. Active Users (last 30 days)
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final activeUsersQuery = await _firestore
          .collection('users')
          .where('lastActive', isGreaterThanOrEqualTo: thirtyDaysAgo)
          .count()
          .get();
      final activeUsers = activeUsersQuery.count ?? 0;

      // 2. New Users (this month)
      final newUsersQuery = await _firestore
          .collection('users')
          .where('createdAt', isGreaterThanOrEqualTo: startOfMonth)
          .count()
          .get();
      final newUsersThisMonth = newUsersQuery.count ?? 0;

      // 3. Total Applications (this month)
      final applicationsQuery = await _firestore
          .collection('jobApplications')
          .where('appliedAt', isGreaterThanOrEqualTo: startOfMonth)
          .count()
          .get();
      final applicationsThisMonth = applicationsQuery.count ?? 0;

      // 4. Job Fill Rate
      final totalJobsQuery = await _firestore.collection('jobs').count().get();
      final filledJobsQuery = await _firestore
          .collection('jobs')
          .where('status', isEqualTo: 'closed') // Assuming 'closed' means filled
          .count()
          .get();
          
      final totalJobs = totalJobsQuery.count ?? 1;
      final filledJobs = filledJobsQuery.count ?? 0;
      final jobFillRate = (totalJobs > 0) ? (filledJobs / totalJobs) * 100 : 0.0;

      return {
        'activeUsers': activeUsers,
        'newUsersThisMonth': newUsersThisMonth,
        'applicationsThisMonth': applicationsThisMonth,
        'jobFillRate': jobFillRate,
      };
    } catch (e) {
      return {
        'activeUsers': 0,
        'newUsersThisMonth': 0,
        'applicationsThisMonth': 0,
        'jobFillRate': 0.0,
      };
    }
  }

  // Get top 5 job categories by application count
  Future<List<Map<String, dynamic>>> getTopJobCategoriesByApplication() async {
    try {
      // For simplicity, we count jobs per category. A more complex query would be needed
      // to count actual applications per category, possibly requiring data denormalization.
      final jobsSnapshot = await _firestore.collection('jobs').get();
      final categoryCounts = <String, int>{};

      for (var doc in jobsSnapshot.docs) {
        final category = doc.data()['category'] as String? ?? 'Other';
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }

      final sortedCategories = categoryCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final topCategories = sortedCategories.take(5).map((e) => {
        'category': e.key,
        'count': e.value,
      }).toList();

      return topCategories;

    } catch (e) {
      return [];
    }
  }

  // Get top 5 companies by job post count (as a proxy for applications)
  Future<List<Map<String, dynamic>>> getTopCompaniesByJobCount() async {
    try {
      final jobsSnapshot = await _firestore.collection('jobs').get();
      final companyCounts = <String, int>{};

      for (var doc in jobsSnapshot.docs) {
        // Correctly read the 'company' field and provide a default value.
        final company = doc.data().containsKey('company') && doc.data()['company'] != null
            ? doc.data()['company'] as String
            : 'Unknown Company';
        
        // Trim whitespace and ensure it's not empty
        final trimmedCompany = company.trim();
        final companyKey = trimmedCompany.isEmpty ? 'Unknown Company' : trimmedCompany;

        companyCounts[companyKey] = (companyCounts[companyKey] ?? 0) + 1;
      }

      final sortedCompanies = companyCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final topCompanies = sortedCompanies.take(5).map((e) => {
        'company': e.key,
        'count': e.value,
      }).toList();

      return topCompanies;

    } catch (e) {
      return [];
    }
  }
} 