import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../models/user_model.dart';
import 'dart:io';


class EmployerSignUpScreen extends StatefulWidget {
  const EmployerSignUpScreen({super.key});

  @override
  State<EmployerSignUpScreen> createState() => _EmployerSignUpScreenState();
}

class _EmployerSignUpScreenState extends State<EmployerSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _industryController = TextEditingController();
  final _websiteController = TextEditingController();
  final _phoneController = TextEditingController();
  // New controllers for verification
  final _ssmNumberController = TextEditingController();
  final _companyAddressController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String? _selectedIndustry;
  
  // New state variable for the selected file
  File? _ssmDocument;
  String? _ssmDocumentName;

  final List<String> _industries = [
    'Technology',
    'Healthcare',
    'Finance',
    'Education',
    'Manufacturing',
    'Retail',
    'Construction',
    'Transportation',
    'Entertainment',
    'Other'
  ];

  @override
  void dispose() {
    _companyNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _industryController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    // Dispose new controllers
    _ssmNumberController.dispose();
    _companyAddressController.dispose();
    super.dispose();
  }

  Future<void> _pickSsmDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _ssmDocument = File(result.files.single.path!);
          _ssmDocumentName = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking document: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadSsmDocument(String userId) async {
    if (_ssmDocument == null) return null;
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('employer_documents')
          .child('$userId/${_ssmDocumentName ?? DateTime.now().toIso8601String()}');
      
      final uploadTask = storageRef.putFile(_ssmDocument!);
      final snapshot = await uploadTask.whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      // ignore: avoid_print
      print('Error uploading SSM document: $e');
      return null;
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedIndustry == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an industry.'), backgroundColor: Colors.orange));
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    String? tempUserId;

    try {
      // ignore: avoid_print
      print('=== STARTING EMPLOYER SIGNUP PROCESS ===');
      
      // Test Firebase connection
      try {
        await FirebaseFirestore.instance.collection('test').doc('test').get();
        // ignore: avoid_print
        print('Firebase connection test successful');
      } catch (e) {
        // ignore: avoid_print
        print('Firebase connection test failed: $e');
        throw Exception('Firebase connection failed. Please check your internet connection.');
      }

      // Step 1: Create Firebase Auth user
      // ignore: avoid_print
      print('Step 1: Creating Firebase Auth user...');
      final result = await authProvider.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        role: 'employer',
      );

      if (!result['success']) {
        throw Exception(result['message'] ?? 'An unknown error occurred during signup.');
      }
      
      tempUserId = result['userId'];
      if (tempUserId == null) {
        throw Exception('Failed to get user ID after registration.');
      }
      // ignore: avoid_print
      print('Step 1: Firebase Auth user created successfully with ID: $tempUserId');

      // Step 2: Upload SSM document if provided
      String? ssmDocUrl;
      if (_ssmDocument != null) {
        // ignore: avoid_print
        print('Step 2: Uploading SSM document...');
        ssmDocUrl = await _uploadSsmDocument(tempUserId);
        if (ssmDocUrl == null) {
          throw Exception('Failed to upload SSM document. Please try again.');
        }
        // ignore: avoid_print
        print('Step 2: SSM document uploaded successfully: $ssmDocUrl');
      } else {
        // ignore: avoid_print
        print('Step 2: No SSM document provided, skipping upload');
      }

      // Step 3: Create UserModel with all form data
      // ignore: avoid_print
      print('Step 3: Creating UserModel...');
      // ignore: avoid_print
      print('Form data:');
      // ignore: avoid_print
      print('  Company Name: ${_companyNameController.text.trim()}');
      // ignore: avoid_print
      print('  Email: ${_emailController.text.trim()}');
      // ignore: avoid_print
      print('  Industry: $_selectedIndustry');
      // ignore: avoid_print
      print('  SSM Number: ${_ssmNumberController.text.trim()}');
      // ignore: avoid_print
      print('  Phone: ${_phoneController.text.trim()}');
      // ignore: avoid_print
      print('  Website: ${_websiteController.text.trim()}');
      // ignore: avoid_print
      print('  Address: ${_companyAddressController.text.trim()}');
      
      final newUser = UserModel(
        uid: tempUserId,
        email: _emailController.text.trim(),
        role: 'employer',
        createdAt: Timestamp.now(),
        // Company information
        name: _companyNameController.text.trim(), // Contact person name
        companyName: _companyNameController.text.trim(),
        phone: _phoneController.text.trim(),
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        industry: _selectedIndustry,
        // Verification information
        ssmNumber: _ssmNumberController.text.trim(),
        companyAddress: _companyAddressController.text.trim(),
        ssmDocumentUrl: ssmDocUrl,
        verificationStatus: 'pending',
        // Initialize counters
        appliedJobs: 0,
        savedJobs: 0,
        interviews: 0,
      );
      // ignore: avoid_print
      print('Step 3: UserModel created successfully');

      // Step 4: Save user to Firestore (basic user record for authentication)
      // ignore: avoid_print
      print('Step 4: Saving to users collection...');
      await userProvider.saveUser(newUser);
      // ignore: avoid_print
      print('Step 4: User saved to users collection successfully');

      // Step 5: Save detailed employer data to employers collection
      // ignore: avoid_print
      print('Step 5: Saving to employers collection...');
      await _saveEmployerData(tempUserId, newUser);
      // ignore: avoid_print
      print('Step 5: Employer data saved to employers collection successfully');

      // ignore: avoid_print
      print('=== EMPLOYER SIGNUP PROCESS COMPLETED SUCCESSFULLY ===');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Please wait for admin approval.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/');
      }

    } catch (e) {
      // ignore: avoid_print
      print('=== EMPLOYER SIGNUP PROCESS FAILED ===');
      // ignore: avoid_print
      print('Error: $e');
      
      // Cleanup: Delete the Firebase Auth user and any created documents if Firestore save failed
      if (tempUserId != null) {
        try {
          // ignore: avoid_print
          print('Starting cleanup process...');
          
          // Delete from users collection
          await FirebaseFirestore.instance.collection('users').doc(tempUserId).delete();
          // ignore: avoid_print
          print('Cleaned up users collection');
          
          // Delete from employers collection
          await FirebaseFirestore.instance.collection('employers').doc(tempUserId).delete();
          // ignore: avoid_print
          print('Cleaned up employers collection');
          
          // Delete Firebase Auth user
          await authProvider.deleteUser(tempUserId);
          // ignore: avoid_print
          print('Cleaned up Firebase Auth user');
        } catch (deleteError) {
          // ignore: avoid_print
          print('Failed to cleanup after error: $deleteError');
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // Header with gradient and icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4A90E2), Color(0xFF5DADE2)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.business_center_outlined,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Title
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF4A90E2), Color(0xFF5DADE2)],
                    ).createShader(bounds),
                    child: const Text(
                      'Create Business Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Join our platform and start hiring top talent',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Company Information Section
                  const Text(
                    'Company Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A90E2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _companyNameController,
                    hintText: 'Company Name',
                    icon: Icons.business,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your company name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Industry Dropdown
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedIndustry,
                      decoration: InputDecoration(
                        hintText: 'Select Industry',
                        prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF4A90E2)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      items: _industries.map((String industry) {
                        return DropdownMenuItem<String>(
                          value: industry,
                          child: Text(industry),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedIndustry = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select an industry';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _websiteController,
                    hintText: 'Company Website (Optional)',
                    icon: Icons.language,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _phoneController,
                    hintText: 'Company Phone Number',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  // Company Verification Section
                  const Text(
                    'Company Verification',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A90E2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _ssmNumberController,
                    hintText: 'SSM Registration Number',
                    icon: Icons.verified_user,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your SSM number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _companyAddressController,
                    hintText: 'Company Address',
                    icon: Icons.location_city,
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your company address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Document Upload Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _pickSsmDocument,
                        borderRadius: BorderRadius.circular(15),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.upload_file, color: Color(0xFF4A90E2)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  _ssmDocumentName ?? 'Upload SSM Document (PDF, IMG)',
                                  style: TextStyle(
                                    color: _ssmDocumentName != null
                                        ? const Color(0xFF1F2937)
                                        : const Color(0xFF6B7280),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Account Information Section
                  const Text(
                    'Account Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A90E2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _emailController,
                    hintText: 'Business Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _passwordController,
                    hintText: 'Password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    isPasswordVisible: _isPasswordVisible,
                    onTogglePasswordVisibility: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _confirmPasswordController,
                    hintText: 'Confirm Password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    isPasswordVisible: _isConfirmPasswordVisible,
                    onTogglePasswordVisibility: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  // Sign Up Button
                  Container(
                    height: 55,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A90E2), Color(0xFF5DADE2)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Sign In Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: Color(0xFF4A90E2),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    bool? isPasswordVisible,
    VoidCallback? onTogglePasswordVisibility,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int? maxLines,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !(isPasswordVisible ?? false),
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Color(0xFF1F2937)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
          prefixIcon: Icon(icon, color: const Color(0xFF4A90E2)),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isPasswordVisible ?? false
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: const Color(0xFF4A90E2),
                  ),
                  onPressed: onTogglePasswordVisibility,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }



  Future<void> _saveEmployerData(String userId, UserModel user) async {
    try {
      // ignore: avoid_print
      print('=== SAVING EMPLOYER DATA ===');
      // ignore: avoid_print
      print('User ID: $userId');
      // ignore: avoid_print
      print('User email: ${user.email}');
      // ignore: avoid_print
      print('Company name: ${user.companyName}');
      
      final employerData = {
        'uid': userId,
        'email': user.email,
        'companyName': user.companyName,
        'contactPerson': user.name,
        'phone': user.phone,
        'website': user.website,
        'industry': user.industry,
        'ssmNumber': user.ssmNumber,
        'companyAddress': user.companyAddress,
        'ssmDocumentUrl': user.ssmDocumentUrl,
        'status': 'pending', // This matches the verificationStatus in users collection
        'createdAt': user.createdAt,
        'updatedAt': Timestamp.now(),
      };

      // ignore: avoid_print
      print('Employer data to save:');
      employerData.forEach((key, value) {
        // ignore: avoid_print
        print('  $key: $value');
      });

      // ignore: avoid_print
      print('Attempting to save to employers collection...');
      await FirebaseFirestore.instance.collection('employers').doc(userId).set(employerData);
      
      // ignore: avoid_print
      print('=== EMPLOYER DATA SAVED SUCCESSFULLY ===');
      
      // Verify the data was saved by reading it back
      final savedDoc = await FirebaseFirestore.instance.collection('employers').doc(userId).get();
      if (savedDoc.exists) {
        // ignore: avoid_print
        print('Verification: Document exists in employers collection');
        // ignore: avoid_print
        print('Saved data: ${savedDoc.data()}');
      } else {
        // ignore: avoid_print
        print('WARNING: Document does not exist after save!');
      }
      
    } catch (e) {
      // ignore: avoid_print
      print('=== ERROR SAVING EMPLOYER DATA ===');
      // ignore: avoid_print
      print('Error details: $e');
      // ignore: avoid_print
      print('Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        // ignore: avoid_print
        print('Firebase error code: ${e.code}');
        // ignore: avoid_print
        print('Firebase error message: ${e.message}');
      }
      throw Exception('Failed to save employer data: $e');
    }
  }
} 