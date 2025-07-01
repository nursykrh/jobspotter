import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = true;
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;

  UserProvider() {
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    // Check if user is already signed in
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await loadUser(currentUser.uid);
    } else {
      _isLoading = false;
      notifyListeners();
    }
    
    // Listen to auth state changes
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    _isLoading = true;
    notifyListeners();

    if (firebaseUser == null) {
      _user = null;
    } else {
      await loadUser(firebaseUser.uid);
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> loadUser(String uid) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      _user = await _firebaseService.getUser(uid);
    } catch (e) {
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUser(UserModel user) async {
    try {
      await _firebaseService.updateUser(user);
      _user = user;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  Future<UserModel?> getUserById(String uid) async {
    try {
      return await _firebaseService.getUser(uid);
    } catch (e) {
      return null;
    }
  }
  
  Future<void> saveUser(UserModel user) async {
     try {
      await _firebaseService.saveUser(user);
      _user = user;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  void clearUser() {
    _user = null;
    _isLoading = false;
    notifyListeners();
  }

  // Force refresh user data
  Future<void> refreshUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await loadUser(currentUser.uid);
    } else {
      _user = null;
      _isLoading = false;
      notifyListeners();
    }
  }
} 