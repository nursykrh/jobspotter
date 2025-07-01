import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/user_stats_service.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploading = false;

  // Controllers for all fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _positionController = TextEditingController();
  final _experienceController = TextEditingController();
  final _educationController = TextEditingController();
  final _languagesController = TextEditingController();
  final _skillsController = TextEditingController();
  List<String> _skills = [];

  @override
  void initState() {
    super.initState();
    // Force load user data when tab is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also load user data when dependencies change (like when navigating back to this tab)
    _loadUserData();
  }

  void _loadUserData() async {
    if (!mounted) return;
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // If we have auth but no user data loaded, force a refresh
    if (authProvider.user != null && userProvider.user == null && !userProvider.isLoading) {
      await userProvider.loadUser(authProvider.user!.uid);
    }
    
    // Also try refreshing if we have stale data (no name)
    if (authProvider.user != null && userProvider.user != null && 
        (userProvider.user!.name == null || userProvider.user!.name!.isEmpty)) {
      await userProvider.refreshUser();
    }
    
    // Auto-fix statistics if they're all 0 (likely missing from old user accounts)
    if (authProvider.user != null && userProvider.user != null && 
        userProvider.user!.appliedJobs == 0 && 
        userProvider.user!.savedJobs == 0 && 
        userProvider.user!.interviews == 0) {
      _autoRecalculateStatsIfNeeded(authProvider.user!.email ?? '');
    }
    
    // Initialize form fields with current user data
    if (!_isEditing && userProvider.user != null) {
      _initializeFields(userProvider.user);
    }
  }

  void _initializeFields(UserModel? user) {
    if (user != null) {
      _nameController.text = user.name ?? '';
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
      _locationController.text = user.location ?? '';
      _positionController.text = user.position ?? '';
      _experienceController.text = user.experience ?? '';
      _educationController.text = user.education ?? '';
      _languagesController.text = user.languages ?? '';
      _skills = List<String>.from(user.skills ?? []);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _positionController.dispose();
    _experienceController.dispose();
    _educationController.dispose();
    _languagesController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!mounted) return;
    setState(() => _isSaving = true);

    final userProvider = Provider.of<UserProvider>(context, listen:false);
    final currentUser = userProvider.user;
    final authUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error: User not found. Please log in again.'),
        backgroundColor: Colors.red,
      ));
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    // Secure Email Update
    final newEmail = _emailController.text.trim();
    if (newEmail != currentUser.email) {
      try {
        await authUser.verifyBeforeUpdateEmail(newEmail);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('A verification link has been sent to your new email.'),
            backgroundColor: Colors.orange,
          ));
        }
      } on FirebaseAuthException catch (e) {
        String message = 'Failed to update email.';
        if (e.code == 'requires-recent-login') {
          message = 'This is a sensitive action. Please log out and log back in, then try again.';
        } else if (e.code == 'email-already-in-use') {
          message = 'This email is already in use by another account.';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
        }
        if (mounted) setState(() => _isSaving = false);
        return; 
      }
    }

    final updatedUser = currentUser.copyWith(
      name: _nameController.text.trim(),
      email: newEmail, // Use the potentially updated email
      phone: _phoneController.text.trim(),
      location: _locationController.text.trim(),
      position: _positionController.text.trim(),
      experience: _experienceController.text.trim(),
      education: _educationController.text.trim(),
      languages: _languagesController.text.trim(),
      skills: _skills,
    );

    try {
      await userProvider.updateUser(updatedUser);
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showImageSourceDialog(UserModel user) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndUploadImage(user, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndUploadImage(user, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage(UserModel user, [ImageSource? source]) async {
    if (!mounted) return;
    setState(() => _isUploading = true);
    final imagePicker = ImagePicker();
    try {
      // Request permissions if needed
      final pickedFile = await imagePicker.pickImage(
        source: source ?? ImageSource.gallery, 
        imageQuality: 60,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      
      if (pickedFile == null) {
        if (mounted) setState(() => _isUploading = false);
        return;
      }

      File imageFile = File(pickedFile.path);
      
      // Check file size (limit to 5MB)
      final fileSize = await imageFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image size too large. Please choose an image smaller than 5MB.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        if (mounted) setState(() => _isUploading = false);
        return;
      }

      // Create storage reference with timestamp to avoid conflicts
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${user.uid}_$timestamp.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child(fileName);

      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'userId': user.uid},
      );

      final uploadTask = storageRef.putFile(imageFile, metadata);
      
      // Monitor upload progress (optional)
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (mounted) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          // You can show progress here if needed
          debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
        }
      });

      // Wait for upload to complete
      final taskSnapshot = await uploadTask;
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();
      
      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.updateUser(user.copyWith(profileImage: downloadUrl));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        String errorMessage;
        switch (e.code) {
          case 'storage/unauthorized':
            errorMessage = 'Permission denied. Please check Firebase Storage rules.';
            break;
          case 'storage/canceled':
            errorMessage = 'Upload was canceled.';
            break;
          case 'storage/unknown':
            errorMessage = 'An unknown error occurred during upload.';
            break;
          case 'storage/object-not-found':
            errorMessage = 'File not found.';
            break;
          case 'storage/bucket-not-found':
            errorMessage = 'Storage bucket not found.';
            break;
          case 'storage/project-not-found':
            errorMessage = 'Project not found.';
            break;
          case 'storage/quota-exceeded':
            errorMessage = 'Storage quota exceeded.';
            break;
          case 'storage/unauthenticated':
            errorMessage = 'User is not authenticated. Please login again.';
            break;
          case 'storage/retry-limit-exceeded':
            errorMessage = 'Upload failed after multiple retries.';
            break;
          case 'storage/invalid-checksum':
            errorMessage = 'File was corrupted during upload.';
            break;
          default:
            errorMessage = 'Upload failed: ${e.message}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _pickAndUploadImage(user, source),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _pickAndUploadImage(user, source),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    showDialog(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
              title: const Text('Confirm Logout'),
              content: const Text('Are you sure you want to logout?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                TextButton(
                  child: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    Navigator.of(dialogContext).pop(); 
                    try {
                      await Provider.of<AuthProvider>(context, listen: false).safeSignOut(context);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error logging out: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        // Show loading spinner
        if (userProvider.isLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFFF0F7FF),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (userProvider.user == null) {
          // Check if we have auth but no user data - automatically try to refresh
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          if (authProvider.user != null) {
            // Automatically trigger refresh on first render
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                userProvider.refreshUser();
              }
            });
            
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Loading profile data...', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        await userProvider.refreshUser();
                      },
                      child: const Text("Refresh Profile"),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _handleLogout,
                      child: const Text("Logout"),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Could not load profile. Please try logging in again.', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _handleLogout,
                      child: const Text("Logout"),
                    )
                  ],
                ),
              ),
            );
          }
        }

        // Initialize fields here, only when user data is confirmed available.
        if (!_isEditing) {
          _initializeFields(userProvider.user);
        }
        
        return _isEditing 
          ? _buildProfileForm(context) 
          : _buildCompleteProfile(context, userProvider.user!);
      },
    );
  }

  Widget _buildCompleteProfile(BuildContext context, UserModel user) {
    final bool hasImage = user.profileImage != null && user.profileImage!.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF4A90E2),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4A90E2), Color(0xFF5DADE2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          backgroundImage: hasImage ? NetworkImage(user.profileImage!) : null,
                          onBackgroundImageError: hasImage ? (e, s) {} : null,
                          child: !hasImage
                              ? Text(
                                  user.name?.isNotEmpty == true ? user.name![0].toUpperCase() : 'U',
                                  style: const TextStyle(fontSize: 40, color: Color(0xFF4A90E2), fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isUploading ? null : () => _showImageSourceDialog(user),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF4A90E2))),
                              child: _isUploading
                                  ? const SizedBox(
                                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.camera_alt, color: Color(0xFF4A90E2), size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(user.name ?? 'No Name',
                        style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(user.position ?? 'No Position',
                        style: const TextStyle(fontSize: 16, color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFFF0F7FF),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatBox('Applied', user.appliedJobs),
                  _buildStatBox('Saved', user.savedJobs),
                  _buildStatBox('Interviews', user.interviews),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    _buildInfoCard(
                      children: [
                        _buildInfoRow(Icons.person_outline, user.name, title: "Full Name", placeholder: "Please enter your name"),
                        _buildInfoRow(Icons.email_outlined, user.email, title: "Email"),
                        _buildInfoRow(Icons.phone_outlined, user.phone, title: "Phone", placeholder: "Please enter your phone number"),
                        _buildInfoRow(Icons.location_on_outlined, user.location, title: "Location", placeholder: "Please enter your location"),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildInfoCard(
                      children: [
                        _buildInfoRow(Icons.work_outline, user.position, title: 'Position', placeholder: "Please enter your desired position"),
                        _buildInfoRow(Icons.trending_up, user.experience, title: 'Experience', placeholder: "Please enter your experience"),
                        _buildInfoRow(Icons.school_outlined, user.education, title: 'Education', placeholder: "Please enter your education"),
                        _buildInfoRow(Icons.language_outlined, user.languages, title: 'Languages', placeholder: "Please enter languages"),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (user.skills != null && user.skills!.isNotEmpty)
                      _buildSkillsCard(user.skills!),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // When edit is pressed, re-initialize fields to ensure they have the latest user data
                          _initializeFields(user); 
                          setState(() => _isEditing = true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF4A90E2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFF4A90E2)),
                          ),
                          elevation: 1,
                        ),
                        child: const Text('Edit Profile', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleLogout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Logout', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // BUILD THE EDIT FORM UI
  Widget _buildProfileForm(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Lighter background for the form
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: const Text('Edit Profile', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () => setState(() => _isEditing = false), // Go back to view mode
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Using the new _buildTextField for a consistent look
            _buildTextField(controller: _nameController, label: 'Full Name', icon: Icons.person_outline),
            _buildTextField(controller: _emailController, label: 'Email', icon: Icons.email_outlined),
            _buildTextField(controller: _phoneController, label: 'Phone', icon: Icons.phone_outlined),
            _buildTextField(controller: _locationController, label: 'Location', icon: Icons.location_on_outlined),
            _buildTextField(controller: _positionController, label: 'Current/Desired Position', icon: Icons.work_outline),
            _buildTextField(controller: _experienceController, label: 'Experience', icon: Icons.trending_up),
            _buildTextField(controller: _educationController, label: 'Education', icon: Icons.school_outlined),
            _buildTextField(controller: _languagesController, label: 'Languages', icon: Icons.language_outlined),
            const SizedBox(height: 24),
            _buildSkillsInput(), // The skills input widget
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                    : const Text('Save Profile', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // A helper to build styled TextFields for the edit form
  Widget _buildTextField(
      {required TextEditingController controller, required String label, required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey[500]),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
          ),
        ),
      ),
    );
  }

  // Widget for adding and removing skills
  Widget _buildSkillsInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Skills', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          TextField(
            controller: _skillsController,
            decoration: InputDecoration(
              hintText: 'Add a skill and press +',
              border: InputBorder.none,
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_circle, color: Color(0xFF4A90E2)),
                onPressed: () {
                  final skill = _skillsController.text.trim();
                  if (skill.isNotEmpty && !_skills.contains(skill)) {
                    setState(() {
                      _skills.add(skill);
                      _skillsController.clear();
                    });
                  }
                },
              ),
            ),
          ),
          if (_skills.isNotEmpty) const Divider(),
          if (_skills.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _skills.map((skill) => Chip(
                          label: Text(skill),
                          backgroundColor: Colors.blue[50],
                          labelStyle: TextStyle(color: Colors.blue[800]),
                          onDeleted: () => setState(() => _skills.remove(skill)),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          deleteIconColor: Colors.red[400],
                        )).toList(),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildSkillsCard(List<String> skills) {
    return _buildInfoCard(
      children: [
        Row(children: [
          Icon(Icons.construction, color: Colors.grey[500]),
          const SizedBox(width: 16),
          const Text('Skills', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: skills.map((skill) => Chip(
            label: Text(skill),
            backgroundColor: const Color(0xFF4A90E2).withValues(alpha: 0.1),
            labelStyle: const TextStyle(color: Color(0xFF4A90E2)),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildStatBox(String title, int count) {
    return Expanded(
      child: GestureDetector(
        onLongPress: () async {
          // Long press to recalculate stats (hidden feature for debugging)
          if (title == 'Applied') {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Recalculate Statistics'),
                content: const Text('This will recalculate your profile statistics. Continue?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Recalculate')),
                ],
              ),
            );
            if (confirm == true && mounted) {
              try {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final userProvider = Provider.of<UserProvider>(context, listen: false);
                if (authProvider.user != null) {
                  await UserStatsService.recalculateUserStats(authProvider.user!.email ?? '');
                  if (mounted) {
                    await userProvider.refreshUser();
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Statistics recalculated successfully!'), backgroundColor: Colors.green),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error recalculating stats: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            }
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4A90E2)),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(IconData icon, String? value, {String? title, String? placeholder}) {
    final bool isProvided = value != null && value.isNotEmpty;
    final String displayText = isProvided ? value : (placeholder ?? 'Not provided');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[500]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 16,
                    color: isProvided ? Colors.black87 : Colors.grey.shade600,
                    fontStyle: isProvided ? FontStyle.normal : FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to automatically recalculate stats for users with missing counter data
  Future<void> _autoRecalculateStatsIfNeeded(String userEmail) async {
    try {
      await UserStatsService.recalculateUserStats(userEmail);
      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.refreshUser();
      }
    } catch (e) {
      // Silently handle errors - this is just a background fix
    }
  }
}

