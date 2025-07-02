import 'package:flutter/material.dart';
import 'tabs/home_tab.dart';
import 'tabs/recommend_tab.dart';
import 'tabs/activity_tab.dart';
import 'tabs/profile_tab.dart';
import 'notifications_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:badges/badges.dart' as badges;
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userEmail = Provider.of<AuthProvider>(context, listen: false).user?.email ?? '';
    final List<Widget> screens = [
      const HomeTab(),
      const RecommendTab(),
      const ActivityTab(),
      NotificationsScreen(userEmail: userEmail),
      const ProfileTab(),
    ];
    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userEmail', isEqualTo: userEmail)
            .where('isRead', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          int unreadCount = 0;
          if (snapshot.hasData) {
            unreadCount = snapshot.data!.docs.length;
          }
          return Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF6C63FF),
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
              items: [
                const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
                const BottomNavigationBarItem(
              icon: Icon(Icons.work_outline),
              activeIcon: Icon(Icons.work),
              label: 'Recommend',
            ),
                const BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_border),
              activeIcon: Icon(Icons.bookmark),
              label: 'Saved',
            ),
            BottomNavigationBarItem(
                  icon: badges.Badge(
                    showBadge: unreadCount > 0,
                    badgeContent: Text(
                      unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    child: const Icon(Icons.message),
                  ),
              label: 'Notification',
            ),
                const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
          );
        },
      ),
    );
  }
} 