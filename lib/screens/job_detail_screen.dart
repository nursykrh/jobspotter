import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job.dart';
import '../providers/user_provider.dart';
import 'job_application_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/user_stats_service.dart';

class JobDetailScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  const JobDetailScreen({Key? key, required this.job}) : super(key: key);

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late Job _job;
  bool _isSaved = false;
  String? _userId;
  Position? _currentPosition;
  Map<String, dynamic>? _transportInfo;
  bool _isLoadingTransport = false;
  bool _isStrongApplicant = false;
  bool _isLoadingApplicantStatus = true;

  // --- UI Theme Colors ---
  final Color _primaryColor = const Color(0xFF0D47A1); // A nice, professional blue
  final Color _scaffoldBgColor = Colors.white;
  final Color _secondaryTextColor = Colors.black87; // Changed to black for readability

  @override
  void initState() {
    super.initState();
    // This handles both DocumentSnapshot and Map data sources
    if (widget.job is DocumentSnapshot) {
      _job = Job.fromFirestore(widget.job as DocumentSnapshot<Map<String, dynamic>>);
    } else {
      _job = Job.fromMap(widget.job);
    }
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      if (mounted) {
        setState(() {
          _userId = user.uid;
        });
      }
      _loadSavedStatus(); 
      _determineApplicantStatus();
    _getCurrentLocation();
    } else {
      if (mounted) {
        setState(() {
          _isLoadingApplicantStatus = false;
        });
      }
    }
  }

  Future<void> _determineApplicantStatus() async {
    if (_userId == null) {
      if (mounted) setState(() => _isLoadingApplicantStatus = false);
      return;
    }

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final UserModel? currentUser = userProvider.user;

      if (currentUser != null && currentUser.skills?.isNotEmpty == true && _job.skills.isNotEmpty) {
        final userSkills = currentUser.skills!.map((s) => s.toLowerCase()).toSet();
        final jobSkills = _job.skills.map((s) => s.toLowerCase()).toSet();
        final intersection = userSkills.intersection(jobSkills);
        if (intersection.isNotEmpty && mounted) {
          setState(() {
            _isStrongApplicant = true;
          });
        }
      }
    } catch (e) {
      // Could not determine status, default to false
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingApplicantStatus = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        if (_job.latitude != 0.0 && _job.longitude != 0.0) {
          _getTransportInfo();
        }
      }
    } catch (e) {
      // Could not get location
    }
  }

  Future<void> _getTransportInfo() async {
    if (_currentPosition == null) return;

    if (mounted) setState(() => _isLoadingTransport = true);

    try {
      double distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _job.latitude,
        _job.longitude,
      );
      double distanceInKm = distanceInMeters / 1000;

      // More realistic time estimates
      String carTime = (distanceInKm * 2).round().toString(); // Avg speed ~30km/h in city
      String busTime = (distanceInKm * 4).round().toString(); // Avg speed ~15km/h with stops
      String walkTime = (distanceInKm * 12).round().toString(); // Avg speed ~5km/h
      String grabFare = (distanceInKm * 1.5 + 4).toStringAsFixed(2);
      String busFare = "2.00"; 

      if (mounted) {
        setState(() {
          _transportInfo = {
            'distance': '${distanceInKm.toStringAsFixed(1)} km',
            'carTime': carTime,
            'busTime': busTime,
            'walkTime': walkTime,
            'grabFare': 'RM$grabFare',
            'busFare': 'RM$busFare',
          };
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoadingTransport = false);
    }
  }

  Future<void> _loadSavedStatus() async {
    if (_userId == null || _job.id.isEmpty) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(_userId!).collection('savedJobs').doc(_job.id).get();
    if (mounted) {
      setState(() {
        _isSaved = doc.exists;
      });
    }
  }

  Future<void> _toggleSaveJob() async {
    if (_userId == null || _job.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to save jobs.')));
      return;
    }

    final bool originalSaveStatus = _isSaved;
    if (mounted) {
      setState(() {
        _isSaved = !_isSaved;
      });
    }

    try {
      if (_isSaved) {
        await UserStatsService.saveJob(_userId!, _job.id, _job.toFirestore());
      } else {
        await UserStatsService.unsaveJob(_userId!, _job.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isSaved ? 'Job saved!' : 'Job unsaved')));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaved = originalSaveStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating saved status: $e')));
      }
    }
  }

  void _shareJob() {
    Share.share(
      'Check out this job: ${_job.title} at ${_job.company}!\nFind more details here: [Link to job posting if available]', // Replace with a real link if you have one
      subject: 'Job Opportunity: ${_job.title}',
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.share, color: _primaryColor),
              title: const Text('Share Job'),
              onTap: () {
                Navigator.pop(context);
                _shareJob();
              },
            ),
            ListTile(
              leading: Icon(Icons.report, color: Colors.red[700]),
              title: const Text('Report Job'),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog();
              },
            ),
          ],
        );
      },
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Report Job'),
          content: const Text('Are you sure you want to report this job posting?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Report'),
              onPressed: () {
                // Implement actual report logic here
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Job reported. Thank you for your feedback.')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _scaffoldBgColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: _primaryColor,
            ),
            onPressed: _toggleSaveJob,
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.grey[800]),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            if (_isLoadingApplicantStatus)
              const Center(child: CircularProgressIndicator())
            else if (_isStrongApplicant) ...[
              _buildStrongApplicantBanner(),
              const SizedBox(height: 24),
            ],
            _buildJobHeader(),
            const SizedBox(height: 24),
            _buildInfoSection(),
            const SizedBox(height: 24),
            _buildApplyButton(),
            const SizedBox(height: 24),
            _buildHowYouMatchCard(),
            const SizedBox(height: 24),
            _buildCompanyProfileCard(),
            const SizedBox(height: 24),
            if (_job.latitude != 0.0 && _job.longitude != 0.0) ...[
              _buildHowToGetThereCard(),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStrongApplicantBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD), // A light blue, matching the theme
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
          Icon(Icons.check_circle_outline, color: _primaryColor, size: 28),
          const SizedBox(width: 16),
                    Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You may be a strong applicant!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                    fontSize: 16,
                ),
              ),
                const SizedBox(height: 2),
                Text(
                  'Your skills align with this job\'s requirements.',
                  style: TextStyle(color: _primaryColor.withValues(alpha: 0.8), fontSize: 13),
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _job.title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _job.company, // Use _job.company
          style: TextStyle(
            fontSize: 18,
            color: _secondaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        _buildInfoRow(Icons.location_on_outlined, _job.location),
        _buildInfoRow(
          Icons.work_outline,
          _job.experience,
        ),
        _buildInfoRow(Icons.access_time_outlined, _job.employmentType),
        _buildInfoRow(Icons.attach_money_outlined, _job.salary.isNotEmpty ? 'RM ${_job.salary}' : 'Salary not disclosed'),
        _buildInfoRow(
          Icons.history_toggle_off_outlined,
          'Posted ${timeago.format(_job.postedDate)}',
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    if (text.isEmpty || text.toLowerCase() == 'not specified') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Icon(icon, color: _secondaryTextColor, size: 20),
          const SizedBox(width: 16),
                Expanded(
                            child: Text(
              text,
              style: TextStyle(fontSize: 15, color: _secondaryTextColor),
                            ),
                          ),
                        ],
                      ),
    );
  }

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobApplicationScreen(job: _job.toJson()),
            ),
          );
        },
        child: const Text(
          'Apply now',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildHowYouMatchCard() {
    if (_job.skills.isEmpty) return const SizedBox.shrink();
    return _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const Row(
            children: [
              Text(
                'How you match',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 8),
              Icon(Icons.info_outline, color: Colors.black87, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Skills and credentials from the job description',
            style: TextStyle(color: _secondaryTextColor, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _job.skills.map((skill) => _buildSkillChip(skill)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyProfileCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About the Company',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _primaryColor.withValues(alpha: 0.1),
                child: Text(
                  _job.company.isNotEmpty ? _job.company[0] : 'C',
                  style: TextStyle(color: _primaryColor, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                    Text(
                      _job.company,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Information not provided', // Placeholder
                      style: TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),
          ],
        ),
        ],
      ),
    );
  }

  Widget _buildHowToGetThereCard() {
    return _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const Text(
            'How to get there?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          if (_isLoadingTransport)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_isLoadingTransport && _transportInfo != null) ...[
            const SizedBox(height: 16),
            _buildTransportInfoRow(Icons.directions_car, 'By Car', '${_transportInfo!['carTime']!} min', 'Grab: ${_transportInfo!['grabFare']!}'),
            _buildTransportInfoRow(Icons.directions_bus, 'By Bus', '${_transportInfo!['busTime']!} min', 'Fare: ${_transportInfo!['busFare']!}'),
            _buildTransportInfoRow(Icons.directions_walk, 'By Walking', '${_transportInfo!['walkTime']!} min', _transportInfo!['distance']!),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final mapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=${_job.latitude},${_job.longitude}');
                  if (await canLaunchUrl(mapsUrl)) {
                    await launchUrl(mapsUrl);
                  }
                },
                child: const Text('View on Google Maps'),
            ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransportInfoRow(IconData icon, String title, String time, String details) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: _primaryColor, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(time, style: TextStyle(color: _secondaryTextColor)),
          ],
        ),
          const Spacer(),
          Text(details, style: TextStyle(color: _secondaryTextColor)),
        ],
      ),
    );
  }

  Widget _buildSkillChip(String skill) {
    return Chip(
      label: Text(skill, style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w500)),
      backgroundColor: _primaryColor.withValues(alpha: 0.1),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: _scaffoldBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            spreadRadius: 1,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
