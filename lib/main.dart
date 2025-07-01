import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'providers/job_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'routes.dart';

Future<void> updateNotificationsUserEmail() async {
  final notifications = await FirebaseFirestore.instance.collection('notifications').get();
  for (final doc in notifications.docs) {
    final data = doc.data();
 
    if (data['userEmail'] == null && data['toEmail'] != null) {
      await doc.reference.update({'userEmail': data['toEmail']});
      // Updated notification with userEmail: ${data['toEmail']}
    }
  }
  // All notifications updated!
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Add debug prints
  // Initializing Firebase...
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Firebase initialized successfully

    // Remove or comment out the following lines to prevent auto-creating admin:
    // final authProvider = AuthProvider();
    // await authProvider.initializeAdminAccount();
    // Admin account initialized

  } catch (e) {
    // Error initializing Firebase: $e
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
       
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JobSpotter',
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey,
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      onGenerateRoute: Routes.generateRoute,
      // Fallback for undefined routes
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }
}
