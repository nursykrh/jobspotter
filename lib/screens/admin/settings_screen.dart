import 'package:flutter/material.dart';
import 'admin_profile.dart';
import 'admin_guidelines.dart';
import 'about_us.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 0;

  final List<Widget> _settingsSections = const [
    AdminProfile(),
    AdminGuidelines(),
    AboutUs(),
  ];

  final List<String> _sectionTitles = const [
    'Profile',
    'Guidelines',
    'About Us',
  ];

  final List<IconData> _sectionIcons = const [
    Icons.person,
    Icons.rule_folder,
    Icons.info,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Navigation Rail
        NavigationRail(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          labelType: NavigationRailLabelType.all,
          destinations: List.generate(
            _sectionTitles.length,
            (index) => NavigationRailDestination(
              icon: Icon(_sectionIcons[index]),
              label: Text(_sectionTitles[index]),
            ),
          ),
        ),

        // Vertical Divider
        const VerticalDivider(thickness: 1, width: 1),

        // Content Area
        Expanded(
          child: SingleChildScrollView(
            child: _settingsSections[_selectedIndex],
          ),
        ),
      ],
    );
  }
} 