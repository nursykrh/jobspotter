import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/profile_edit_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/map_screen.dart';
import 'screens/employer/employer_dashboard_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/employer_signup_screen.dart';
import 'screens/employer/post_job_screen.dart';
import 'screens/notifications_screen.dart';

class Routes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (context) {
        final auth = Provider.of<AuthProvider>(context);
        
        // If user is not logged in, only allow access to public routes
        if (auth.user == null) {
          switch (settings.name) {
            case '/':
            case '/login':
              return const LoginScreen();
            case '/signup':
              return const SignUpScreen();
            case '/employer-signup':
              return const EmployerSignUpScreen();
            default:
              return const LoginScreen();
          }
        }

        // Show loading screen while checking status
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Route guards based on user role and status
        switch (settings.name) {
          case '/':
          case '/login':
            if (auth.isAdmin) {
              return const AdminDashboardScreen();
            } else if (auth.isApprovedEmployer) {
              return const EmployerDashboardScreen();
            } else if (auth.isRejectedEmployer || auth.isPendingEmployer) {
              return _buildEmployerStatusScreen(auth);
            } else {
              return const HomeScreen();
            }

          case '/home':
            // Jobseekers and approved users can access home
            if (auth.isAdmin) {
              return const AdminDashboardScreen();
            } else if (auth.isApprovedEmployer) {
              return const EmployerDashboardScreen();
            } else if (auth.isRejectedEmployer || auth.isPendingEmployer) {
              return _buildEmployerStatusScreen(auth);
            } else {
              return const HomeScreen();
            }

          case '/profile':
            // All authenticated users can access profile
            return const ProfileScreen();

          case '/profile-edit':
            // All authenticated users can edit profile
            return const ProfileEditScreen();

          case '/profile-setup':
            // All authenticated users can set up profile
            return const ProfileSetupScreen();

          case '/map':
            // All authenticated users can access map
            return const MapScreen();

          case '/notifications':
            // All authenticated users can access notifications
            final userEmail = settings.arguments as String? ?? auth.user?.email ?? '';
            return NotificationsScreen(userEmail: userEmail);

          case '/admin-dashboard':
            if (auth.isAdmin) {
              return const AdminDashboardScreen();
            }
            return _buildAccessDeniedScreen();

          case '/employer-dashboard':
            if (auth.isApprovedEmployer) {
              return const EmployerDashboardScreen();
            } else if (auth.isRejectedEmployer || auth.isPendingEmployer) {
              return _buildEmployerStatusScreen(auth);
            }
            return _buildAccessDeniedScreen(
              message: 'Access denied. Employer access only.'
            );

          case '/post-job':
            if (auth.isApprovedEmployer) {
              return const PostJobScreen();
            }
            return _buildAccessDeniedScreen(
              message: 'Access denied. Employer access only.'
            );

          default:
            // Default to home for authenticated users
            if (auth.isAdmin) {
              return const AdminDashboardScreen();
            } else if (auth.isApprovedEmployer) {
              return const EmployerDashboardScreen();
            } else if (auth.isRejectedEmployer || auth.isPendingEmployer) {
              return _buildEmployerStatusScreen(auth);
            } else {
              return const HomeScreen();
            }
        }
      },
    );
  }

  static Widget _buildAccessDeniedScreen({String? message}) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Denied'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                message ?? 'You do not have permission to access this page.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(
                  NavigationService.navigatorKey.currentContext!
                ).pushReplacementNamed('/'),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildEmployerStatusScreen(AuthProvider auth) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.signOut();
              if (NavigationService.navigatorKey.currentContext != null) {
                Navigator.of(NavigationService.navigatorKey.currentContext!)
                    .pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                auth.isRejectedEmployer ? Icons.cancel : Icons.hourglass_empty,
                size: 64,
                color: auth.isRejectedEmployer ? Colors.red : Colors.orange,
              ),
              const SizedBox(height: 24),
              Text(
                auth.isRejectedEmployer
                    ? 'Your employer account has been rejected'
                    : 'Your account is pending approval',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                auth.isRejectedEmployer
                    ? 'Please contact support for more information.'
                    : 'Please wait while admin reviews your application.',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  await auth.signOut();
                  if (NavigationService.navigatorKey.currentContext != null) {
                    Navigator.of(NavigationService.navigatorKey.currentContext!)
                        .pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Navigation service to handle navigation from outside the widget tree
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}

final Map<String, WidgetBuilder> routes = {
  '/': (context) => const LoginScreen(),
  '/signup': (context) => const SignUpScreen(),
  '/employer-signup': (context) => const EmployerSignUpScreen(),
  '/profile-setup': (context) => const ProfileSetupScreen(),
  '/home': (context) => const HomeScreen(),
  '/profile': (context) => const ProfileScreen(),
  '/profile-edit': (context) => const ProfileEditScreen(),
  '/map': (context) => const MapScreen(),
  '/employer-dashboard': (context) => const EmployerDashboardScreen(),
  '/admin-dashboard': (context) => const AdminDashboardScreen(),
  '/post-job': (context) => const PostJobScreen(),
  '/notifications': (context) => NotificationsScreen(
    userEmail: ModalRoute.of(context)?.settings.arguments as String,
  ),
}; 