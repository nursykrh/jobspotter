import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Needed for UID
import '../models/user_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create or Update a user document in Firestore
  Future<void> saveUser(UserModel user) async {
    try {
      // ignore: avoid_print
      print('Saving user to Firestore: ${user.uid}');
      // ignore: avoid_print
      print('User data: ${user.toMap()}');
      
      await _firestore.collection('users').doc(user.uid).set(user.toMap());
      
      // ignore: avoid_print
      print('User saved successfully to Firestore');
    } catch (e) {
      // ignore: avoid_print
      print('Error saving user to Firestore: $e');
      throw Exception('Failed to save user: $e');
    }
  }

  // Get a user document from Firestore by UID
  Future<UserModel?> getUser(String uid) async {
    try {
      final docRef = _firestore.collection('users').doc(uid);
      final doc = await docRef.get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        // == ONE-TIME MIGRATION/PATCH ==
        // This checks if the counter fields are null in the DB and fixes them.
        // This repairs existing user accounts that were created before the fields were non-nullable.
        final Map<String, dynamic> updates = {};
        if (data['appliedJobs'] == null) updates['appliedJobs'] = 0;
        if (data['savedJobs'] == null) updates['savedJobs'] = 0;
        if (data['interviews'] == null) updates['interviews'] = 0;

        if (updates.isNotEmpty) {
          await docRef.update(updates);
          // Merge updates into local data so the UI updates instantly without a re-fetch.
          data.addAll(updates);
        }
        // == END MIGRATION/PATCH ==

        // Ensure the UID from the document ID is in the map.
        data['uid'] = doc.id;
        return UserModel.fromMap(data);
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Failed to get user: $e');
      throw Exception('Failed to get user: $e');
    }
  }

  // Get current user as a UserModel
  Future<UserModel?> getCurrentUserModel() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;
    return await getUser(currentUser.uid);
  }

  // Update a user document in Firestore
  Future<void> updateUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update(user.toMap());
    } catch (e) {
      // ignore: avoid_print
      print('Failed to update user: $e');
      throw Exception('Failed to update user: $e');
    }
  }

  // This function seems dangerous and specific, keeping it as is but noting it.
  Future<void> deleteDuplicateAdmins(String keepUid) async {
    final admins = await FirebaseFirestore.instance.collection('admins').get();
    for (final doc in admins.docs) {
      if (doc.id != keepUid) {
        await doc.reference.delete();
      }
    }
    // ignore: avoid_print
    print('Deleted all admin docs except $keepUid');
  }

  Future<UserModel> createNewUser({
    required String uid,
    required String email,
    required String role,
    Map<String, dynamic>? additionalData,
  }) async {
    final user = UserModel(
      uid: uid,
      email: email,
      role: role,
      createdAt: Timestamp.now(),
      name: additionalData?['fullName'] ?? additionalData?['companyName'],
      companyName: additionalData?['companyName'],
      phone: additionalData?['phone'],
      location: additionalData?['companyAddress'],
      verificationStatus: additionalData?['verificationStatus'] ?? (role == 'jobseeker' ? 'verified' : 'pending'),
      ssmNumber: additionalData?['ssmNumber'],
      companyAddress: additionalData?['companyAddress'],
      ssmDocumentUrl: additionalData?['ssmDocumentUrl'],
      // Explicitly set counters to 0 for new users, aligning with the robust model.
      appliedJobs: 0,
      savedJobs: 0,
      interviews: 0,
    );
    await _firestore.collection('users').doc(uid).set(user.toMap());
    return user;
  }
} 