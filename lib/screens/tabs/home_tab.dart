import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'dart:async';
import '../job_application_screen.dart';
import '../job_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'dart:math';
import 'message_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/user_stats_service.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final TextEditingController _searchController = TextEditingController();
  final loc.Location _location = loc.Location();
  final Completer<GoogleMapController> _controller = Completer();
  bool _isSearchFocused = false;
  bool _showMap = false;
  String _selectedLocation = '';

  // Default to center of Peninsular Malaysia
  static const LatLng _defaultLocation = LatLng(3.140853, 101.693207); // Kuala Lumpur
  static const double _defaultZoom = 10.0;

  // Add category state
  String _selectedCategory = 'All';
  
  // Add category data
  final List<Map<String, dynamic>> _categories = [
    {
      'title': 'All',
      'icon': Icons.all_inclusive,
      'color': const Color(0xFF6C63FF),
      'backgroundColor': const Color(0xFFF0EFFF),
    },
    {
      'title': 'Tech',
      'icon': Icons.laptop,
      'color': const Color(0xFF2196F3),
      'backgroundColor': const Color(0xFFE3F2FD),
    },
    {
      'title': 'Business',
      'icon': Icons.business_center,
      'color': const Color(0xFF4CAF50),
      'backgroundColor': const Color(0xFFE8F5E9),
    },
    {
      'title': 'Retail',
      'icon': Icons.shopping_bag,
      'color': const Color(0xFF009688), // Teal
      'backgroundColor': const Color(0xFFE0F2F1),
    },
    {
      'title': 'Education',
      'icon': Icons.school,
      'color': const Color(0xFFFF9800),
      'backgroundColor': const Color(0xFFFFF3E0),
    },
  ];

  LatLng? _searchedLatLng;

  double _selectedRadius = 10.0;
  final List<double> _radiusOptions = [5.0, 10.0, 20.0, 50.0];
  Position? _currentPosition;
  List<Map<String, dynamic>> _allJobs = [];
  Set<String> _savedJobIds = {};

  bool _useCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _selectedLocation = _selectedLocation.isEmpty ? "Kuala Lumpur" : _selectedLocation;
    _searchedLatLng ??= _defaultLocation;
    _getCurrentLocation();
    _fetchJobsAndSavedStatus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    var permissionGranted = await _location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) return;
    }
  }

  Future<void> _fetchJobsAndSavedStatus() async {
    await _fetchJobs();
    await _fetchSavedJobIds();
  }
  
  Future<void> _fetchSavedJobIds() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    if (userId == null || userId.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('savedJobs')
        .get();
        
    if (mounted) {
      setState(() {
        _savedJobIds = snapshot.docs.map((doc) => doc.id).toSet();
      });
    }
  }

  Future<void> _getAndSetCurrentLocation() async {
    final locData = await _location.getLocation();
    if (locData.latitude != null && locData.longitude != null) {
        setState(() {
        _searchedLatLng = LatLng(locData.latitude!, locData.longitude!);
        _useCurrentLocation = true;
        });
      if (_controller.isCompleted) {
        final controller = await _controller.future;
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(_searchedLatLng!, 13),
        );
      }
    }
  }

  Future<void> _navigateToDetail(Map<String, dynamic> job) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailScreen(job: job),
      ),
    );
    // When returning from detail screen, refresh saved status
    await _fetchSavedJobIds();
  }

  // Method to save/unsave job
  Future<void> _toggleSaveJob(Map<String, dynamic> job) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    if (userId == null || userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to save jobs.')));
      }
      return;
    }

    final jobId = job['id']?.toString();
    if (jobId == null || jobId.isEmpty) {
      return;
    }

    // Optimistic UI update
    final bool isCurrentlySaved = _savedJobIds.contains(jobId);
    if (mounted) {
      setState(() {
        if (isCurrentlySaved) {
          _savedJobIds.remove(jobId);
        } else {
          _savedJobIds.add(jobId);
        }
      });
    }

    try {
      if (isCurrentlySaved) {
        // It's already saved, so unsave it
        await UserStatsService.unsaveJob(userId, jobId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job unsaved.')));
        }
      } else {
        // It's not saved, so save it
        final jobDataToSave = Map<String, dynamic>.from(job);
        jobDataToSave.remove('id');
        await UserStatsService.saveJob(userId, jobId, jobDataToSave);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job saved!')));
        }
      }
    } catch (e) {
      // Revert UI on error
      if (mounted) {
        setState(() {
          if (isCurrentlySaved) {
            _savedJobIds.add(jobId);
          } else {
            _savedJobIds.remove(jobId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating saved status: $e')));
      }
    }
  }

  Future<void> _searchByLocation() async {
    if (_searchController.text.isEmpty) return;
    try {
      List<geo.Location> locations = await geo.locationFromAddress(_searchController.text);
      if (locations.isNotEmpty) {
        final location = locations.first;
    setState(() {
          _selectedLocation = _searchController.text;
          _showMap = true;
          _searchedLatLng = LatLng(location.latitude, location.longitude);
        });
        final GoogleMapController controller = await _controller.future;
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(location.latitude, location.longitude),
            13,
        ),
      );
    }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find location. Please try again.')),
        );
      }
    }
  }

  double _calculateDistance(LatLng a, LatLng b) {
    const double earthRadius = 6371000; // meters
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);
    final sindLat = sin(dLat / 2);
    final sindLng = sin(dLng / 2);
    final va = sindLat * sindLat + cos(_deg2rad(a.latitude)) * cos(_deg2rad(b.latitude)) * sindLng * sindLng;
    final vc = 2 * atan2(sqrt(va), sqrt(1 - va));
    return earthRadius * vc;
  }
  double _deg2rad(double deg) => deg * (pi / 180.0);

  void _showJobPopup(Map<String, dynamic> job) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue[50],
                    child: Icon(Icons.business, color: Colors.blue[300]),
                  ),
                  const SizedBox(width: 12),
                  Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                      Text(job['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(job['company'] ?? '', style: const TextStyle(color: Colors.grey)),
                    ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
              Text(job['description'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
                  Row(
                    children: [
                  const Icon(Icons.location_on, size: 18, color: Colors.blue),
                      const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job['location'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                      ),
                      const SizedBox(width: 16),
                  const Icon(Icons.attach_money, size: 18, color: Colors.green),
                      const SizedBox(width: 4),
                  Text(job['salary'] ?? ''),
                ],
              ),
                  const SizedBox(height: 16),
              Row(
                      children: [
                        Expanded(
              child: ElevatedButton(
                onPressed: () {
                        Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JobApplicationScreen(job: job),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Apply Now'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MessageScreen(job: job),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Message'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final address = Uri.encodeComponent(job['location'] ?? '');
                      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$address');
                      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open Google Maps')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.navigation, color: Colors.white),
                    label: const Text('Navigate', style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    
    // Check if the widget is still in the tree before calling setState
    if (mounted) {
      setState(() {
        _currentPosition = pos;
      });
    }
    
    _filterJobs();
  }

  Future<void> _fetchJobs() async {
    // Fetch all jobs from Firestore, filter will be applied on the client-side
    final snapshot = await FirebaseFirestore.instance.collection('jobs').get();
    final jobs = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id; // Ensure the document ID is included
      return data;
    }).toList();
    
    // Check if the widget is still in the tree before calling setState
    if (mounted) {
      setState(() {
        _allJobs = jobs;
      });
    }
    
    _filterJobs();
  }

  void _filterJobs() {
    if (_currentPosition == null) {
      return;
    }
    _allJobs.where((job) {
      final lat = job['latitude'];
      final lng = job['longitude'];
      if (lat == null || lng == null) return false;
      final distance = _calculateDistance(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        LatLng(lat, lng),
      );
      return distance <= _selectedRadius * 1000; // Convert km to meters
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          // Disable scrolling when map is shown to allow map gestures
          physics: _showMap ? const NeverScrollableScrollPhysics() : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Custom App Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    spreadRadius: 0,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.work_outline,
                          color: Color(0xFF6C63FF),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'JobSpotter',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_none),
                      color: Colors.grey[600],
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Container(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (value) => _searchByLocation(),
                        decoration: InputDecoration(
                          hintText: 'Search jobs by location',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onTap: () {
                          setState(() {
                            _isSearchFocused = true;
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.my_location,
                        color: Color(0xFF6C63FF),
                      ),
                        onPressed: () async {
                          await _getAndSetCurrentLocation();
                          setState(() {
                            _useCurrentLocation = true;
                          });
                        },
                    ),
                  ],
                ),
              ),
            ),

            if (_isSearchFocused)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.my_location, color: Color(0xFF6C63FF)),
                      title: const Text('Use current location'),
                      onTap: () {
                          _getAndSetCurrentLocation();
                        setState(() {
                          _isSearchFocused = false;
                        });
                      },
                    ),
                  ],
                ),
              ),

            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = _selectedCategory == category['title'];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category['title'];
                              _fetchJobs(); // Refetch jobs when category changes
                            });
                          },
                          child: Container(
                            width: 82,
                            margin: EdgeInsets.only(
                              right: index == _categories.length - 1 ? 0 : 12,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected 
                                ? category['color'].withValues(alpha: 0.1)
                                : category['backgroundColor'],
                              borderRadius: BorderRadius.circular(16),
                              border: isSelected
                                ? Border.all(
                                    color: category['color'],
                                    width: 2,
                                  )
                                : null,
                              boxShadow: [
                                BoxShadow(
                                  color: category['color'].withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                      ? category['color'].withValues(alpha: 0.2)
                                      : category['color'].withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    category['icon'],
                                    color: category['color'],
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  category['title'],
                                  style: TextStyle(
                                    color: category['color'],
                                    fontSize: 13,
                                    fontWeight: isSelected 
                                      ? FontWeight.bold 
                                      : FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

              // Toggle List/Map button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showMap = !_showMap;
                      });
                    },
                    child: Text(_showMap ? 'Show List' : 'Show Map'),
                  ),
                ],
              ),

              // Dropdown radius hanya jika _useCurrentLocation true
              if (_useCurrentLocation)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text('Show jobs within:'),
                      const SizedBox(width: 8),
                      DropdownButton<double>(
                        value: _selectedRadius,
                        items: _radiusOptions.map((r) => DropdownMenuItem(
                          value: r,
                          child: Text('${r.toInt()} km'),
                        )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedRadius = value;
                            });
                            _filterJobs();
                          }
                        },
                      ),
                    ],
                  ),
                ),

              // Main Content
              if (_showMap)
                Container(
                  height: 400,
                  // Allow gestures to pass through to the map
                  decoration: const BoxDecoration(),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _searchedLatLng ?? _defaultLocation,
                      zoom: _defaultZoom,
                    ),
                    // Enable all gestures for user-friendly interaction
                    zoomGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    rotateGesturesEnabled: true,
                    // Enable zoom controls and compass
                    zoomControlsEnabled: true,
                    compassEnabled: true,
                    // Enable location features
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    markers: _allJobs.where((job) {
                      final matchCategory = _selectedCategory == 'All' ||
                        (job['category'] ?? '').toString().toLowerCase() == _selectedCategory.toLowerCase();
                      if (_useCurrentLocation && _searchedLatLng != null && job['latitude'] != null && job['longitude'] != null) {
                        final distance = _calculateDistance(
                          _searchedLatLng!,
                          LatLng(job['latitude'] as double, job['longitude'] as double),
                        );
                        return matchCategory && distance <= _selectedRadius * 1000;
                      }
                      return matchCategory;
                    }).map((job) {
                      return Marker(
                        markerId: MarkerId(job['id'] ?? job['title']),
                        position: LatLng(job['latitude'] as double, job['longitude'] as double),
                        infoWindow: InfoWindow(
                          title: job['title'] ?? 'No Title',
                          snippet: job['company'] ?? 'No Company',
                        ),
                        onTap: () => _showJobPopup(job),
                      );
                    }).toSet(),
                    circles: _useCurrentLocation && _searchedLatLng != null
                              ? {
                                  Circle(
                                    circleId: const CircleId('search_radius'),
                                    center: _searchedLatLng!,
                              radius: _selectedRadius * 1000,
                                    fillColor: Colors.blue.withValues(alpha: 0.1),
                                    strokeColor: Colors.blue,
                                    strokeWidth: 2,
                                  ),
                                }
                              : {},
                          onMapCreated: (controller) {
                            _controller.complete(controller);
                          },
                        ),
                ),
              if (!_showMap)
                Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(Provider.of<AuthProvider>(context, listen: false).user?.uid ?? '')
                          .collection('savedJobs')
                          .snapshots(),
                        builder: (context, snapshot) {
                          final Set<String> savedJobIds = {};
                          if (snapshot.hasData) {
                            for (var doc in snapshot.data!.docs) {
                              savedJobIds.add(doc.id);
                            }
                          }
                          final List<Map<String, dynamic>> jobsToShow = _allJobs.where((job) {
                            final matchCategory = _selectedCategory == 'All' ||
                              (job['category'] ?? '').toString().toLowerCase() == _selectedCategory.toLowerCase();
                            if (_useCurrentLocation && _searchedLatLng != null && job['latitude'] != null && job['longitude'] != null) {
                              final distance = _calculateDistance(
                                _searchedLatLng!,
                                LatLng(job['latitude'] as double, job['longitude'] as double),
                              );
                              return matchCategory && distance <= _selectedRadius * 1000;
                            }
                            return matchCategory;
                          }).toList();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(jobsToShow.length, (index) {
                              final job = jobsToShow[index];
                              final isSaved = savedJobIds.contains(job['id']?.toString() ?? '');
                              return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                                child: _buildJobCard(job, isSaved),
                              );
                            }),
                    );
                  },
                      ),
                    ],
                  ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  // Update JobCard to show saved status
  Widget _buildJobCard(Map<String, dynamic> job, bool isSaved) {
    final List<String> skills = (job['skills'] is List)
        ? List<String>.from(job['skills'])
        : (job['skills']?.toString().split(',') ?? []);

    return GestureDetector(
      onTap: () => _navigateToDetail(job),
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[100]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Company Logo or Icon
                Container(
                  width: 46,
                  height: 46,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    job['icon']?.toString() ?? '🏢',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 16),
                // Company and Job Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job['company']?.toString() ?? 'No Company',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job['title']?.toString() ?? 'No Title',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Bookmark and Match Percentage
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_outline,
                        color: const Color(0xFF6C63FF),
                      ),
                      onPressed: () => _toggleSaveJob(job),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${90 + (job.hashCode % 10)}% Match',
                        style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Location and Salary
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    job['location']?.toString() ?? 'No Location',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  job['salary']?.toString() ?? '-',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Skills Tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills.map((skill) => Chip(
                label: Text(
                  skill,
                  style: const TextStyle(
                    color: Color(0xFF6C63FF),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.1),
              )).toList(),
            ),
            const SizedBox(height: 16),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => JobApplicationScreen(job: job),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Apply Now',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    // Message functionality placeholder
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6C63FF),
                    side: const BorderSide(color: Color(0xFF6C63FF)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const CategoryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class JobCard extends StatelessWidget {
  final String company;
  final String title;
  final String location;
  final String salary;

  const JobCard({
    super.key,
    required this.company,
    required this.title,
    required this.location,
    required this.salary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.business,
                  color: Color(0xFF6C63FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.bookmark_border,
                  color: Color(0xFF6C63FF),
                ),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                location,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                salary,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}