import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  User? _user;
  String? _role;
  String? _employerStatus;
  bool _isLoading = false;

  User? get user => _user;
  String? get role => _role;
  String? get employerStatus => _employerStatus;
  bool get isLoading => _isLoading;

  bool get isEmployer => _role != null && _role == 'employer';
  bool get isAdmin => _role != null && _role == 'admin';
  bool get isApprovedEmployer => isEmployer && _employerStatus == 'approved';
  bool get isRejectedEmployer => isEmployer && _employerStatus == 'rejected';
  bool get isPendingEmployer => isEmployer && _employerStatus == 'pending';

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _user = user;
    if (user != null) {
      await _loadUserData(user.uid);
    } else {
      _role = null;
      _employerStatus = null;
      _isLoading = false; // Ensure loading state is cleared
    }
    notifyListeners();
  }

  Future<void> _loadUserData(String uid) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get user role from Firestore
      final userDoc = await _firestore.collection('users').doc(uid).get();
      _role = userDoc.data()?['role'] as String?;

      // If user is an employer, get their status and set up real-time listener
      if (_role == 'employer') {
        // Set up real-time listener for employer status
        _firestore.collection('employers').doc(uid).snapshots().listen((snapshot) {
          final newStatus = snapshot.data()?['status'] as String?;
          if (_employerStatus != newStatus) {
            _employerStatus = newStatus;
            
            // If employer is rejected or pending, sign them out automatically
            if (newStatus == 'rejected' || newStatus == 'pending') {
              signOut();
            }
            notifyListeners();
          }
        });

        // Get initial status
        final employerDoc = await _firestore.collection('employers').doc(uid).get();
        _employerStatus = employerDoc.data()?['status'] as String?;

        // If employer is rejected or pending, sign them out
        if (_employerStatus == 'rejected' || _employerStatus == 'pending') {
          await signOut();
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> signUp(String email, String password, {String? role}) async {
    try {
      _isLoading = true;
      notifyListeners();

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('User creation failed, please try again.');
      }

      // Return user data on success
      return {
        'success': true,
        'userId': user.uid,
      };
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered. Please sign in instead.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          message = 'Password should be at least 6 characters.';
          break;
        default:
          message = e.message ?? 'An error occurred';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.'
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _user = userCredential.user;
      if (_user == null) {
        return false;
      }

      // Check user role from Firestore
      final userDoc = await _firestore.collection('users').doc(_user!.uid).get();
      
      // If user doc doesn't exist, check if they're an approved employer
      if (!userDoc.exists) {
        final employerDoc = await _firestore.collection('employers').doc(_user!.uid).get();
        if (employerDoc.exists && employerDoc.data()?['status'] == 'approved') {
          _role = 'employer';
          // User document missing but employer is approved - allowing login
        } else {
          await signOut(); // If no user record, sign out
          throw 'User data not found. Please contact support.';
        }
      } else {
        final userData = userDoc.data()!;
        _role = userData['role'];
      }

      if (_role == 'employer') {
        // Check employer status from the employers collection (more reliable)
        final employerDoc = await _firestore.collection('employers').doc(_user!.uid).get();
        if (!employerDoc.exists) {
          await signOut();
          throw 'Employer data not found. Please contact support.';
        }
        
        final employerData = employerDoc.data()!;
        final status = employerData['status']; // Use 'status' field from employers collection
        
        if (status == 'pending') {
          await signOut();
          throw 'Your account is pending approval from the admin.';
        }
        if (status == 'rejected') {
          await signOut();
          throw 'Your account has been rejected. Please contact support for more information.';
        }
        if (status != 'approved') {
          await signOut();
          throw 'Your account is not approved. Please contact support.';
        }
        _employerStatus = status;
      }
      
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'An error occurred during sign in.';
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Clear local state first to prevent UI flickers
      _user = null;
      _role = null;
      _employerStatus = null;
      notifyListeners();
      
      // Then sign out from Firebase
      await _auth.signOut();
      await _googleSignIn.signOut();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> safeSignOut(BuildContext context) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Clear auth state first
      _user = null;
      _role = null;
      _employerStatus = null;
      notifyListeners();
      
      // Sign out from Firebase
      await _auth.signOut();
      await _googleSignIn.signOut();
      
      // Navigate to login screen and clear all previous routes
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      debugPrint('Error during safe signout: $e');
      // Fallback: just sign out normally and navigate
      await signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      // This is a sensitive operation and should be handled with care.
      // It's assumed that this is called for cleanup after a failed registration.
      final userToDelete = _auth.currentUser;
      if (userToDelete != null && userToDelete.uid == uid) {
        await userToDelete.delete();
      }
    } catch (e) {
      // Log this error, but don't throw, as this is a cleanup operation
      debugPrint('Failed to delete temporary user: $e');
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // Create/update user document in Firestore
      await _firestore.collection('jobseekers').doc(userCredential.user!.uid).set({
        'email': userCredential.user!.email,
        'name': userCredential.user!.displayName,
        'photoUrl': userCredential.user!.photoURL,
        'lastSignIn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return userCredential;
    } catch (e) {
      // Error during Google sign in: $e
      return null;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      // First check if the email exists in Firestore
      final employersQuery = await _firestore
          .collection('employers')
          .where('email', isEqualTo: email)
          .get();
      
      final adminsQuery = await _firestore
          .collection('admins')
          .where('email', isEqualTo: email)
          .get();

      // If email exists in employers or admins collection, throw error
      if (employersQuery.docs.isNotEmpty || adminsQuery.docs.isNotEmpty) {
        throw 'This email is registered as an employer or admin. Please contact support for password reset.';
      }

      // Send password reset email
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw 'No user found with this email address.';
        case 'invalid-email':
          throw 'Please enter a valid email address.';
        default:
          throw e.message ?? 'An error occurred while resetting password.';
      }
    } catch (e) {
      throw e.toString();
    }
  }
} 