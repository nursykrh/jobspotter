import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:intl/intl.dart';
import '../models/job.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'employer/post_job_screen.dart';
import '../services/application_service.dart';

class EmployerDashboardScreen extends StatefulWidget {
  const EmployerDashboardScreen({super.key});

  @override
  State<EmployerDashboardScreen> createState() => _EmployerDashboardScreenState();
}

class _EmployerDashboardScreenState extends State<EmployerDashboardScreen> {
  int _selectedIndex = 0;

  Future<void> _handleLogout() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.safeSignOut(context);
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
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    // Double-check employer status
    if (!auth.isApprovedEmployer) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          automaticallyImplyLeading: false,
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
                  auth.employerStatus == 'rejected'
                      ? 'Your account has been rejected. Please contact support for more information.'
                      : auth.employerStatus == 'pending'
                          ? 'Your account is pending approval. Please wait for admin verification.'
                          : 'You do not have permission to access this page.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    await auth.safeSignOut(context);
                  },
                  child: const Text('Back to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Debug: Check employer email access
    final employerEmail = authProvider.user?.email;
    if (employerEmail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final List<Widget> screens = [
      JobPostsTab(employerEmail: employerEmail),
      ApplicationsTab(employerEmail: employerEmail),
      const CompanyProfileTab(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employer Dashboard'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _handleLogout();
                      },
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            label: 'Job Posts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'Applications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business_outlined),
            label: 'Company',
          ),
        ],
        selectedItemColor: const Color(0xFF4A90E2),
      ),
    );
  }
}

class JobPostsTab extends StatefulWidget {
  final String? employerEmail;
  const JobPostsTab({super.key, this.employerEmail});
  @override
  State<JobPostsTab> createState() => _JobPostsTabState();
}

class _JobPostsTabState extends State<JobPostsTab> {
  @override
  Widget build(BuildContext context) {
    // Debug: Check employer email in job posts tab
    return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Job Postings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showPostJobDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Post New Job'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
        ),
              Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('jobs')
                .where('employerEmail', isEqualTo: widget.employerEmail)
                .snapshots(),
            builder: (context, snapshot) {
              // Debug: Check stream data
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No job postings yet.'));
              }
              final jobs = snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return Job.fromJson(data);
              }).toList();
              return ListView.builder(
                            itemCount: jobs.length,
                            itemBuilder: (context, index) {
                              final job = jobs[index];
                              return JobCard(job: job);
                },
              );
                            },
                          ),
              ),
            ],
        );
  }

  void _showPostJobDialog() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PostJobScreen()),
    );
  }
}



class JobCard extends StatelessWidget {
  final Job job;
  const JobCard({super.key, required this.job});

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job'),
        content: const Text('Are you sure you want to delete this job posting?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('jobs').doc(job.id).delete();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Job deleted successfully')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => EditJobDialog(job: job),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.deepPurple[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.work_outline, color: Colors.deepPurple, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A2EFF)),
                        ),
                        const SizedBox(height: 2),
                        Text(job.company, style: const TextStyle(color: Colors.grey, fontSize: 15)),
                      ],
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditDialog(context);
                    } else if (value == 'delete') {
                      _showDeleteConfirmation(context);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(job.location, style: const TextStyle(fontSize: 14)),
                ),
                Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 2),
                Text(job.salary, style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ...job.skills.where((skill) => skill.isNotEmpty).map((skill) => Chip(
                  label: Text(skill),
                  backgroundColor: Colors.deepPurple[50],
                  labelStyle: const TextStyle(color: Colors.deepPurple),
                )),
                if (job.employmentType.isNotEmpty)
                  Chip(
                    label: Text(job.employmentType),
                    backgroundColor: Colors.green[50],
                    labelStyle: TextStyle(color: Colors.green[800]),
                  ),
                if (job.experience.isNotEmpty)
                  Chip(
                    label: Text(job.experience),
                    backgroundColor: Colors.orange[50],
                    labelStyle: TextStyle(color: Colors.orange[800]),
                  ),
                // Only show 'Not specified' if all are empty
                if (job.skills.every((s) => s.isEmpty) && job.employmentType.isEmpty && job.experience.isEmpty)
                  Chip(
                    label: const Text('Not specified'),
                    backgroundColor: Colors.orange[50],
                    labelStyle: TextStyle(color: Colors.orange[800]),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Posted ${DateFormat('yMMMd').format(job.postedDate)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class PostJobDialog extends StatefulWidget {
  const PostJobDialog({super.key});

  @override
  State<PostJobDialog> createState() => _PostJobDialogState();
}

class _PostJobDialogState extends State<PostJobDialog> {
  final _formKey = GlobalKey<FormState>();
  String title = '';
  String company = '';
  String location = '';
  String salary = '';
  String employmentType = 'Full-time';
  String experience = '';
  String description = '';
  List<String> skills = [];
  final skillsController = TextEditingController();

  @override
  void dispose() {
    skillsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Post New Job'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Job Title'),
                validator: (v) => v == null || v.isEmpty ? 'Enter job title' : null,
                onSaved: (v) => title = v ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Company Name'),
                validator: (v) => v == null || v.isEmpty ? 'Enter company name' : null,
                onSaved: (v) => company = v ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Location'),
                validator: (v) => v == null || v.isEmpty ? 'Enter location' : null,
                onSaved: (v) => location = v ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Salary (e.g. RM 7,000 - 10,000)'),
                validator: (v) => v == null || v.isEmpty ? 'Enter salary' : null,
                onSaved: (v) => salary = v ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Experience (e.g. 3+ years)'),
                validator: (v) => v == null || v.isEmpty ? 'Enter experience' : null,
                onSaved: (v) => experience = v ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
                validator: (v) => v == null || v.isEmpty ? 'Enter description' : null,
                onSaved: (v) => description = v ?? '',
              ),
              TextFormField(
                controller: skillsController,
                decoration: InputDecoration(
                  labelText: 'Skills (comma separated)',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      final text = skillsController.text.trim();
                      if (text.isNotEmpty) {
                        setState(() {
                          skills.addAll(text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
                          skillsController.clear();
                        });
                      }
                    },
                  ),
                ),
              ),
              if (skills.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Wrap(
                    spacing: 6,
                    children: skills.map((s) => Chip(label: Text(s))).toList(),
                  ),
                ),
              DropdownButtonFormField<String>(
                value: employmentType,
                items: const [
                  DropdownMenuItem(value: 'Full-time', child: Text('Full-time')),
                  DropdownMenuItem(value: 'Part-time', child: Text('Part-time')),
                  DropdownMenuItem(value: 'Contract', child: Text('Contract')),
                  DropdownMenuItem(value: 'Internship', child: Text('Internship')),
                ],
                onChanged: (v) => setState(() => employmentType = v ?? 'Full-time'),
                decoration: const InputDecoration(labelText: 'Employment Type'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              final job = Job(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: title,
                company: company,
                location: location,
                description: description,
                salary: salary,
                skills: skills,
                companyLogo: '',
                matchPercentage: 0,
                employmentType: employmentType,
                experience: experience,
                postedDate: DateTime.now(),
                employerEmail: authProvider.user?.email ?? '',
                employerId: '', // Assuming employerId is empty
                latitude: 0.0,
                longitude: 0.0,
                category: '',
                companyProfile: '',
              );
              Navigator.of(context).pop(job);
            }
          },
          child: const Text('Post'),
        ),
      ],
    );
  }
}

class ApplicationsTab extends StatefulWidget {
  final String employerEmail;
  const ApplicationsTab({super.key, required this.employerEmail});

  @override
  State<ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends State<ApplicationsTab> {
  late Future<List<Application>> _applicationsFuture;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _refreshApplications();
  }

  void _refreshApplications() {
    final applicationService = ApplicationService();
    setState(() {
      _applicationsFuture = applicationService.getApplicationsForEmployer(widget.employerEmail)
        .then((list) => list.map((data) => Application.fromJson(data, data['id'] ?? '')).toList());
    });
  }
  void _updateStatus(String applicationId, String status, String jobTitle, String company, String jobseekerEmail) async {
    setState(() => _isUpdating = true);
    final applicationService = ApplicationService();
    try {
      await applicationService.updateApplicationStatus(applicationId, status);
      _refreshApplications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isUpdating = false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Application>>(
      future: _applicationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final applications = snapshot.data ?? [];
        if (applications.isEmpty) {
          return const Center(child: Text('No applications yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final app = applications[index];
            // Debug: Check application status
            return GestureDetector(
              onTap: () => _showApplicationDetailDialog(context, app),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: Color(0xFF4A90E2)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              app.jobseekerEmail,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          _buildStatusChip(app.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Job: ${app.jobTitle}', style: const TextStyle(fontSize: 15)),
                      Text('Company: ${app.company}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text('Applied: ${app.appliedAt.toString().substring(0, 10)}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 12),
                      if (app.status == 'Pending')
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _isUpdating ? null : () => _updateStatus(
                                app.id, 'accepted', app.jobTitle, app.company, app.jobseekerEmail,
                              ),
                              icon: const Icon(Icons.check, color: Colors.white),
                              label: const Text('Accept'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _isUpdating ? null : () => _updateStatus(
                                app.id, 'rejected', app.jobTitle, app.company, app.jobseekerEmail,
                              ),
                              icon: const Icon(Icons.close, color: Colors.white),
                              label: const Text('Reject'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'accepted':
        color = Colors.green;
        label = 'Accepted';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejected';
        break;
      default:
        color = Colors.orange;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showApplicationDetailDialog(BuildContext context, Application app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Application Details', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${app.jobseekerEmail}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Job: ${app.jobTitle}'),
              Text('Company: ${app.company}'),
              Text('Applied: ${app.appliedAt.toString().substring(0, 10)}'),
            ],
          ),
        ),
        actions: [
          if (app.status == 'pending') ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateStatus(app.id, 'rejected', app.jobTitle, app.company, app.jobseekerEmail);
              },
              child: const Text('Reject', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateStatus(app.id, 'accepted', app.jobTitle, app.company, app.jobseekerEmail);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Accept'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class CompanyProfileTab extends StatefulWidget {
  const CompanyProfileTab({super.key});

  @override
  State<CompanyProfileTab> createState() => _CompanyProfileTabState();
}

class _CompanyProfileTabState extends State<CompanyProfileTab> {
  bool _isEditing = false;
  final _companyNameController = TextEditingController();
  final _industryController = TextEditingController();
  final _websiteController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCompanyProfile();
  }

  Future<void> _loadCompanyProfile() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('employers').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      _companyNameController.text = data['companyName'] ?? '';
      _industryController.text = data['industry'] ?? '';
      _websiteController.text = data['website'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _addressController.text = data['address'] ?? '';
      setState(() {});
    }
  }

  Future<void> _saveCompanyProfile() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('employers').doc(user.uid).set({
      'companyName': _companyNameController.text,
      'industry': _industryController.text,
      'website': _websiteController.text,
      'phone': _phoneController.text,
      'address': _addressController.text,
      'email': user.email,
      // add other fields as needed
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Company Profile',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(_isEditing ? Icons.close : Icons.edit),
                onPressed: () {
                  setState(() {
                    _isEditing = !_isEditing;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue[50],
                    child: const Icon(Icons.apartment, size: 48, color: Colors.blue),
                  ),
                  const SizedBox(height: 24),
                  _buildProfileField(
                    controller: _companyNameController,
                    label: 'Company Name',
                    icon: Icons.business,
                    enabled: _isEditing,
                  ),
                  _buildProfileField(
                    controller: _industryController,
                    label: 'Industry',
                    icon: Icons.category,
                    enabled: _isEditing,
                  ),
                  _buildProfileField(
                    controller: _websiteController,
                    label: 'Website',
                    icon: Icons.language,
                    enabled: _isEditing,
                  ),
                  _buildProfileField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone,
                    enabled: _isEditing,
                  ),
                  _buildProfileField(
                    controller: _addressController,
                    label: 'Address',
                    icon: Icons.location_on,
                    enabled: _isEditing,
                  ),
                  if (_isEditing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() => _isEditing = false);
                          },
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            _saveCompanyProfile();
                            setState(() => _isEditing = false);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
  }) {
    if (enabled) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListTile(
          leading: Icon(icon, color: Colors.blue),
          title: Text(
            controller.text.isEmpty ? '-' : controller.text,
            style: const TextStyle(fontSize: 16, color: Colors.black),
          ),
          subtitle: Text(label),
          tileColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[300]!),
          ),
        ),
      );
    }
  }
}

class Application {
  final String id;
  final String jobId;
  final String jobseekerEmail;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime appliedAt;
  final String jobTitle;
  final String company;

  Application({
    required this.id,
    required this.jobId,
    required this.jobseekerEmail,
    required this.status,
    required this.appliedAt,
    required this.jobTitle,
    required this.company,
  });

  factory Application.fromJson(Map<String, dynamic> json, String id) {
    final appliedAtRaw = json['appliedAt'] ?? json['appliedDate'];
    DateTime appliedAt;
    if (appliedAtRaw is Timestamp) {
      appliedAt = appliedAtRaw.toDate();
    } else if (appliedAtRaw is String) {
      appliedAt = DateTime.tryParse(appliedAtRaw) ?? DateTime.now();
    } else {
      appliedAt = DateTime.now();
    }
    return Application(
      id: id,
      jobId: json['jobId'] ?? '',
      jobseekerEmail: json['jobseekerEmail'] ?? json['email'] ?? '',
      status: json['status'] ?? '',
      appliedAt: appliedAt,
      jobTitle: json['jobTitle'] ?? '',
      company: json['company'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'jobId': jobId,
    'jobseekerEmail': jobseekerEmail,
    'status': status,
    'appliedAt': appliedAt,
    'jobTitle': jobTitle,
    'company': company,
  };
}

// New: Full Edit Job Dialog
class EditJobDialog extends StatefulWidget {
  final Job job;

  const EditJobDialog({super.key, required this.job});

  @override
  EditJobDialogState createState() => EditJobDialogState();
}

class EditJobDialogState extends State<EditJobDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _salaryController;
  late TextEditingController _skillsController;
  late TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.job.title);
    _descriptionController = TextEditingController(text: widget.job.description);
    _salaryController = TextEditingController(text: widget.job.salary);
    _skillsController = TextEditingController(text: widget.job.skills.join(', '));
    _locationController = TextEditingController(text: widget.job.location);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _salaryController.dispose();
    _skillsController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _updateJob() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Create a new Job object with updated fields
      final updatedJob = Job(
        id: widget.job.id,
        title: _titleController.text,
        company: widget.job.company, // Assuming company doesn't change
        location: _locationController.text,
        description: _descriptionController.text,
        salary: _salaryController.text,
        skills: _skillsController.text.split(',').map((s) => s.trim()).toList(),
        companyLogo: widget.job.companyLogo,
        matchPercentage: widget.job.matchPercentage,
        employmentType: widget.job.employmentType,
        experience: widget.job.experience,
        postedDate: widget.job.postedDate,
        employerEmail: widget.job.employerEmail,
        employerId: widget.job.employerId, // Pass the existing employerId
        latitude: widget.job.latitude,
        longitude: widget.job.longitude,
        category: widget.job.category,
        companyProfile: widget.job.companyProfile,
      );

      // Update in Firestore
      await FirebaseFirestore.instance.collection('jobs').doc(updatedJob.id).set(updatedJob.toJson());

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job updated successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Job'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
            ),
              TextFormField(
                controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
                validator: (value) => value!.isEmpty ? 'Please enter a location' : null,
            ),
              TextFormField(
                controller: _salaryController,
              decoration: const InputDecoration(labelText: 'Salary'),
                validator: (value) => value!.isEmpty ? 'Please enter a salary' : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
              ),
              TextFormField(
                controller: _skillsController,
                decoration: const InputDecoration(labelText: 'Skills (comma-separated)'),
                ),
              ],
            ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton(
          onPressed: _updateJob,
          child: const Text('Update Job'),
        ),
      ],
    );
  }
}