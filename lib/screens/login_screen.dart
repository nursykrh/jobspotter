import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';


enum UserType { jobseeker, employer, admin }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  UserType _selectedUserType = UserType.jobseeker;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Verify credentials
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final success = await authProvider.signIn(
          _emailController.text,
          _passwordController.text,
        );

        if (success) {
          // Verify user type
          bool isValidUserType = false;
          String errorMessage = '';

          if (_selectedUserType == UserType.employer) {
            // Check if user exists in employers collection
            final employerDoc = await FirebaseFirestore.instance
                .collection('employers')
                .doc(authProvider.user!.uid)
                .get();

            if (employerDoc.exists) {
              final employerData = employerDoc.data() as Map<String, dynamic>;
              if (employerData['status'] == 'pending') {
                errorMessage = 'Your account is pending approval. Please wait for admin verification.';
              } else if (employerData['status'] == 'rejected') {
                errorMessage = 'Your account has been rejected. Please contact support for more information.';
              } else {
                isValidUserType = true;
              }
            } else {
              errorMessage = 'This account is not registered as an employer.';
            }
          } else if (_selectedUserType == UserType.admin) {
            // Check if user is admin
            final adminDoc = await FirebaseFirestore.instance
                .collection('admins')
                .doc(authProvider.user!.uid)
                .get();
            
            if (adminDoc.exists) {
              isValidUserType = true;
            } else {
              errorMessage = 'This account does not have admin privileges.';
            }
          } else {
            // For jobseekers, check they're not in employers or admins collection
            final employerDoc = await FirebaseFirestore.instance
                .collection('employers')
                .doc(authProvider.user!.uid)
                .get();
            
            final adminDoc = await FirebaseFirestore.instance
                .collection('admins')
                .doc(authProvider.user!.uid)
                .get();

            if (!employerDoc.exists && !adminDoc.exists) {
              isValidUserType = true;
            } else {
              errorMessage = 'Please select the correct user type for your account.';
            }
          }

          if (isValidUserType) {
            // Load user data from Firestore after successful login
                    if (mounted) {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          await userProvider.loadUser(_emailController.text);
        }

            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              
              // Navigate to different screens based on user type
              switch (_selectedUserType) {
                case UserType.jobseeker:
                  Navigator.of(context).pushReplacementNamed('/home');
                  break;
                case UserType.employer:
                  Navigator.of(context).pushReplacementNamed('/employer-dashboard');
                  break;
                case UserType.admin:
                  Navigator.of(context).pushReplacementNamed('/admin-dashboard');
                  break;
              }
            }
          } else {
            // Sign out if user type is invalid
            await authProvider.signOut();
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMessage),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid email or password'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.signInWithGoogle();

      if (success != null && mounted) {
        // Load user data
        if (mounted) {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          await userProvider.loadUser(authProvider.user!.email!);
        }
        // Navigate to home
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sign in with Google. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final TextEditingController emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your email address and we\'ll send you a link to reset your password.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                
                try {
                  if (mounted) {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    await authProvider.resetPassword(emailController.text);
                    
                    if (mounted) {
                      navigator.pop(); // Close the dialog
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Password reset email sent. Please check your inbox.'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF), // Soft blue background
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFE6F3FF), // Lighter blue
                Color(0xFFF0F7FF), // Soft blue
              ],
            ),
          ),
          child: SingleChildScrollView(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      // User Type Selection
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
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SegmentedButton<UserType>(
                            segments: const [
                              ButtonSegment<UserType>(
                                value: UserType.jobseeker,
                                label: Text('Jobseeker'),
                                icon: Icon(Icons.person_outline),
                              ),
                              ButtonSegment<UserType>(
                                value: UserType.employer,
                                label: Text('Employer'),
                                icon: Icon(Icons.business_center_outlined),
                              ),
                              ButtonSegment<UserType>(
                                value: UserType.admin,
                                label: Text('Admin'),
                                icon: Icon(Icons.admin_panel_settings_outlined),
                              ),
                            ],
                            selected: {_selectedUserType},
                            onSelectionChanged: (Set<UserType> newSelection) {
                              setState(() {
                                _selectedUserType = newSelection.first;
                                _emailController.clear();
                                _passwordController.clear();
                              });
                            },
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith<Color>(
                                (Set<WidgetState> states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return const Color(0xFF4A90E2);
                                  }
                                  return Colors.white;
                                },
                              ),
                              foregroundColor: WidgetStateProperty.resolveWith<Color>(
                                (Set<WidgetState> states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return Colors.white;
                                  }
                                  return const Color(0xFF4A90E2);
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Welcome Text with gradient
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF4A90E2), Color(0xFF5DADE2)],
                        ).createShader(bounds),
                        child: Text(
                          'Welcome ${_selectedUserType.name.substring(0, 1).toUpperCase()}${_selectedUserType.name.substring(1)}!',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to continue your journey',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Illustration
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.network(
                            'https://cdni.iconscout.com/illustration/premium/thumb/login-page-4468581-3783954.png',
                            height: 180,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Email Field
                      _buildInputField(
                        controller: _emailController,
                        hintText: _selectedUserType == UserType.admin 
                            ? 'Admin Email'
                            : _selectedUserType == UserType.employer
                                ? 'Company Email'
                                : 'Email',
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
                      // Password Field
                      _buildInputField(
                        controller: _passwordController,
                        hintText: '${_selectedUserType.name.substring(0, 1).toUpperCase()}${_selectedUserType.name.substring(1)} Password',
                        icon: Icons.lock_outline,
                        isPassword: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      // Forgot Password Button
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Color(0xFF4A90E2),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Login Button with gradient
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
                              color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignIn,
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
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _selectedUserType == UserType.admin 
                                ? "Need admin access? "
                                : "Don't have an account? ",
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          TextButton(
                            onPressed: _selectedUserType == UserType.admin 
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please contact system administrator for admin access.'),
                                        backgroundColor: Color(0xFF4A90E2),
                                      ),
                                    );
                                  }
                                : () {
                                    Navigator.pushNamed(
                                      context,
                                      _selectedUserType == UserType.employer
                                          ? '/employer-signup'
                                          : '/signup',
                                    );
                                  },
                            child: Text(
                              _selectedUserType == UserType.admin
                                  ? 'Contact Admin'
                                  : 'Sign Up',
                              style: const TextStyle(
                                color: Color(0xFF4A90E2),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // OR Divider
                      if (_selectedUserType == UserType.jobseeker) ...[
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Google Sign In Button
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleGoogleSignIn,
                          icon: Image.network(
                            'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                            height: 24,
                          ),
                          label: const Text('Sign in with Google'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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
    TextInputType? keyboardType,
    String? Function(String?)? validator,
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
        obscureText: isPassword && !_isPasswordVisible,
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
                    _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF4A90E2),
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
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
}