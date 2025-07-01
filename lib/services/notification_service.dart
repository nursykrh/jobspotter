import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final _notifications = FirebaseFirestore.instance.collection('notifications');

  // Send notification for new application
  static Future<void> sendApplicationNotification({
    required String jobseekerEmail,
    required String jobTitle,
    required String company,
    required String applicationId,
    required String type,
  }) async {
    String title = '📝 New Application Received';
    String message = 'A new application has been submitted by $jobseekerEmail for $jobTitle position';

    await _notifications.add({
      'userEmail': jobseekerEmail,
      'title': title,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'type': type,
      'jobTitle': jobTitle,
      'company': company,
      'applicationId': applicationId,
      'relatedTo': 'application'
    });
  }

  // Send notification for application status update
  static Future<void> sendJobStatusNotification({
    required String jobseekerEmail,
    required String jobTitle,
    required String company,
    required String status,
  }) async {
    String title;
    String message;

    switch (status.toLowerCase()) {
      case 'accepted':
        title = '🎉 Congratulations!';
        message = 'Great news! Your application for $jobTitle at $company has been accepted.';
        break;
      case 'rejected':
        title = '❌ Application Update';
        message = 'Thank you for your interest. Unfortunately, your application for $jobTitle at $company was not successful this time.';
        break;
      case 'interview':
      case 'shortlisted':
        title = '🙌 You\'re Shortlisted!';
        message = 'Good news! You have been shortlisted for an interview for the $jobTitle role at $company.';
        break;
      case 'applied':
        title = '✅ Application Submitted!';
        message = 'Your application for the $jobTitle position at $company has been successfully submitted.';
        break;
      default:
        title = '📋 Application Update';
        message = 'There is an update on your application for $jobTitle at $company.';
    }

    await _notifications.add({
      'userEmail': jobseekerEmail,
      'title': title,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'type': 'job_status',
      'jobTitle': jobTitle,
      'company': company,
      'status': status,
      'relatedTo': 'application'
    });
  }

  // Get notifications stream for a user
  static Stream<QuerySnapshot> getNotificationsStream(String userEmail) {
    return _notifications
        .where('userEmail', isEqualTo: userEmail)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    await _notifications.doc(notificationId).update({'isRead': true});
  }

  // Get unread notifications count
  static Stream<QuerySnapshot> getUnreadNotificationsStream(String userEmail) {
    return _notifications
        .where('userEmail', isEqualTo: userEmail)
        .where('isRead', isEqualTo: false)
        .snapshots();
  }

  // Delete a notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _notifications.doc(notificationId).delete();
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }

  // Delete all notifications for a user
  static Future<void> deleteAllNotifications(String userEmail) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final notifications = await _notifications
          .where('userEmail', isEqualTo: userEmail)
          .get();
      
      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete notifications: $e');
    }
  }
}
