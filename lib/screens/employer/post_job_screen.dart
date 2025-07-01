import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import '../../providers/auth_provider.dart';
import '../../models/job.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _salaryController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _locationController = TextEditingController();
  final _companyController = TextEditingController();
  final _companyLogoController = TextEditingController();
  final _companyProfileController = TextEditingController();
  String _selectedJobType = 'Part-time';
  bool _isLoading = false;
  LatLng? _selectedLocation;
  final Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  bool _showMap = false;
  String _selectedCategory = 'F&B';
  final List<String> _categories = [
    'F&B', 'Retail', 'Education', 'Healthcare', 'Logistics', 'IT', 'Other'
  ];

  final List<String> _jobTypes = [
    'Part-time',
  ];

  File? _logoImageFile;
  String? _uploadedLogoUrl;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _salaryController.dispose();
    _requirementsController.dispose();
    _locationController.dispose();
    _companyController.dispose();
    _companyLogoController.dispose();
    _companyProfileController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _searchLocation() async {
    if (_locationController.text.isEmpty) return;
    try {
      List<Location> locations = await locationFromAddress(_locationController.text);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final latLng = LatLng(location.latitude, location.longitude);
        setState(() {
          _selectedLocation = latLng;
          _markers.clear();
          _markers.add(
            Marker(
              markerId: const MarkerId('job_location'),
              position: latLng,
              infoWindow: InfoWindow(title: _locationController.text),
            ),
          );
          _showMap = true;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 15),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find location. Please enter a more specific address.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find location. Please enter a more specific address.')),
        );
      }
    }
  }

  Future<void> _pickLogoImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _logoImageFile = File(pickedFile.path);
      });
      // Upload ke Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('company_logos/${DateTime.now().millisecondsSinceEpoch}.png');
      await storageRef.putFile(_logoImageFile!);
      final url = await storageRef.getDownloadURL();
      setState(() {
        _uploadedLogoUrl = url;
      });
    }
  }

  Future<void> _postJob() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final employerEmail = authProvider.user?.email ?? '';
        final employerId = authProvider.user?.uid ?? '';

        _formKey.currentState!.save();

        final job = Job(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text,
          company: _companyController.text,
          location: _locationController.text,
          description: _descriptionController.text,
          salary: _salaryController.text,
          skills: _requirementsController.text.split(',').map((e) => e.trim()).toList(),
          companyLogo: _uploadedLogoUrl ?? '',
          matchPercentage: 0,
          employmentType: _selectedJobType,
          experience: 'Not specified',
          postedDate: DateTime.now(),
          employerEmail: employerEmail,
          employerId: employerId,
          latitude: _selectedLocation!.latitude,
          longitude: _selectedLocation!.longitude,
          category: _selectedCategory,
          companyProfile: _companyProfileController.text,
        );

        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(job.id)
            .set(job.toJson());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job posted successfully!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to post job: ${e.toString()}')),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Post a Job',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF4A90E2),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Job Title
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Job Title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.work),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a job title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Company Name
                TextFormField(
                  controller: _companyController,
                  decoration: InputDecoration(
                    labelText: 'Company Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.business),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a company name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Company Profile
                TextFormField(
                  controller: _companyProfileController,
                  decoration: InputDecoration(
                    labelText: 'Company Profile',
                    hintText: 'Describe your company to attract candidates.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.info_outline),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a company profile';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Job Type Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedJobType,
                  decoration: InputDecoration(
                    labelText: 'Job Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.category),
                  ),
                  items: _jobTypes.map((String type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedJobType = newValue;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Location
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: 'Location',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.location_on),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter location';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _searchLocation,
                      tooltip: 'Search location',
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Map
                if (_showMap)
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _selectedLocation ?? const LatLng(3.1390, 101.6869), // Default to KL
                          zoom: 15,
                        ),
                        markers: _markers,
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                // Salary
                TextFormField(
                  controller: _salaryController,
                  decoration: InputDecoration(
                    labelText: 'Salary Range',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.attach_money),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a salary range';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Requirements
                TextFormField(
                  controller: _requirementsController,
                  decoration: InputDecoration(
                    labelText: 'Requirements (comma-separated)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.list),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter job requirements';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Job Description',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.description),
                  ),
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a job description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Company Logo
                Row(
                  children: [
                    _logoImageFile != null
                        ? CircleAvatar(
                            radius: 28,
                            backgroundImage: FileImage(_logoImageFile!),
                          )
                        : const CircleAvatar(
                            radius: 28,
                            child: Icon(Icons.image, size: 28),
                          ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _pickLogoImage,
                      icon: const Icon(Icons.upload),
                      label: const Text('Upload Logo'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.category),
                  ),
                  items: _categories.map((String cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Post Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _postJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Post Job',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}