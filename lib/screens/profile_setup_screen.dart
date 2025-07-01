import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _positionController = TextEditingController();
  final _experienceController = TextEditingController();
  final _educationController = TextEditingController();
  final _languagesController = TextEditingController();
  final _skillsController = TextEditingController();
  String? _selectedResume;
  List<String> _skills = [];

  @override
  void initState() {
    super.initState();
    // Pre-fill fields with existing user data if available
    final user = Provider.of<UserProvider>(context, listen: false).user;
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

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final existingUser = userProvider.user;

      if (existingUser == null) {
        // Should not happen if user is on this screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User not found. Please restart the app.')),
        );
        return;
      }
      
      final updatedUser = existingUser.copyWith(
        name: _nameController.text,
        // email is not editable here, it's set at signup
        phone: _phoneController.text,
        location: _locationController.text,
        position: _positionController.text,
        experience: _experienceController.text,
        education: _educationController.text,
        languages: _languagesController.text,
        skills: _skills,
      );

      await userProvider.updateUser(updatedUser);
      if(mounted) {
         Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE6F3FF),
              Color(0xFFF0F7FF),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          color: Colors.white,
                          size: 30,
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Complete Your Profile',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Personal Information Section
                  _buildSectionTitle('Personal Information'),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_outline,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    enabled: false,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Email cannot be empty';
                      if (!value!.contains('@')) return 'Please enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _phoneController,
                    label: 'Phone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter your phone number' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _locationController,
                    label: 'Location',
                    icon: Icons.location_on_outlined,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter your location' : null,
                  ),
                  const SizedBox(height: 32),

                  // Professional Information Section
                  _buildSectionTitle('Professional Information'),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _positionController,
                    label: 'Current/Desired Position',
                    icon: Icons.work_outline,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter your desired position' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _experienceController,
                    label: 'Experience',
                    icon: Icons.timeline_outlined,
                    maxLines: 3,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter your experience' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _educationController,
                    label: 'Education',
                    icon: Icons.school_outlined,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter your education' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _languagesController,
                    label: 'Languages',
                    icon: Icons.language_outlined,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter languages you know' : null,
                  ),
                  const SizedBox(height: 32),

                  // Skills Section
                  _buildSectionTitle('Skills'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _skillsController,
                    decoration: InputDecoration(
                      labelText: 'Skills (comma separated)',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          final text = _skillsController.text.trim();
                          if (text.isNotEmpty) {
                            setState(() {
                              _skills.addAll(text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
                              _skillsController.clear();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  if (_skills.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Wrap(
                        spacing: 6,
                        children: _skills.map((s) => Chip(
                          label: Text(s),
                          onDeleted: () {
                            setState(() {
                              _skills.remove(s);
                            });
                          },
                        )).toList(),
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Resume Section
                  _buildSectionTitle('Resume'),
                  const SizedBox(height: 16),
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
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.description_outlined,
                                    color: Color(0xFF4A90E2),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _selectedResume ?? 'No resume uploaded',
                                      style: TextStyle(
                                        color: _selectedResume != null
                                            ? const Color(0xFF1F2937)
                                            : const Color(0xFF6B7280),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                height: 45,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF4A90E2), Color(0xFF5DADE2)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4A90E2).withValues(alpha: 0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    // File picking functionality to be implemented
                                    setState(() {
                                      _selectedResume = 'resume.pdf';
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.upload_file,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Upload Resume',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Supported formats: PDF, DOC, DOCX (Max 5MB)',
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  Container(
                    width: double.infinity,
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
                          color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'Complete Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF4A90E2).withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4A90E2),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool enabled = true,
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
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        validator: validator,
        style: const TextStyle(color: Color(0xFF1F2937)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF6B7280)),
          prefixIcon: Icon(icon, color: const Color(0xFF4A90E2)),
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
} 