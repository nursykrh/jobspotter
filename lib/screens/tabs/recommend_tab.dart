import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/job.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/user_stats_service.dart';
import '../job_application_screen.dart';
import '../job_detail_screen.dart';

class RecommendTab extends StatefulWidget {
  const RecommendTab({super.key});

  @override
  State<RecommendTab> createState() => _RecommendTabState();
}

class _RecommendTabState extends State<RecommendTab> {
  String _selectedFilter = 'All';
  Set<String> _savedJobIds = {};

  @override
  void initState() {
    super.initState();
    _fetchSavedJobIds();
  }

  Future<void> _fetchSavedJobIds() async {
    if (!mounted) return;
    final authProvider =
        Provider.of<app_auth.AuthProvider>(context, listen: false);
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
  
  Future<void> _navigateToDetail(Job job) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailScreen(job: job.toJson()),
      ),
    );
    // When returning from detail screen, refresh saved status
    await _fetchSavedJobIds();
  }

  Future<void> _toggleSaveJob(Job job) async {
    // Prevent calls if widget is disposed
    if (!mounted) return;

    final authProvider =
        Provider.of<app_auth.AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save jobs.')));
      return;
    }

    // Optimistic UI update
    final isCurrentlySaved = _savedJobIds.contains(job.id);
    setState(() {
      if (isCurrentlySaved) {
        _savedJobIds.remove(job.id);
      } else {
        _savedJobIds.add(job.id);
      }
    });

    try {
      if (isCurrentlySaved) {
        await UserStatsService.unsaveJob(userId, job.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Job unsaved.')));
      } else {
        await UserStatsService.saveJob(userId, job.id, job.toFirestore());
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Job saved!')));
      }
    } catch (e) {
      // Revert UI on error
      setState(() {
        if (isCurrentlySaved) {
          _savedJobIds.add(job.id);
        } else {
          _savedJobIds.remove(job.id);
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving job: ${e.toString()}')));
    }
  }

  // Fetches the current user's data from Firestore
  Future<UserModel?> _fetchCurrentUser(String? uid) async {
    if (uid == null) return null;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
    } catch (e) {
      // Handle potential errors, e.g., logging
      debugPrint("Error fetching user: $e");
    }
    return null;
  }

  // Calculates the percentage of matching skills between user and job
  int _calculateMatchPercentage(List<String> userSkills, List<String> jobSkills) {
    if (userSkills.isEmpty || jobSkills.isEmpty) {
      return 0;
    }
    final userSkillsSet = userSkills.map((s) => s.toLowerCase()).toSet();
    final jobSkillsSet = jobSkills.map((s) => s.toLowerCase()).toSet();
    final intersection = userSkillsSet.intersection(jobSkillsSet);
    return ((intersection.length / jobSkillsSet.length) * 100).round();
  }

  Widget _buildActiveFilterDetails(UserModel? currentUser) {
    if (_selectedFilter == 'All' || currentUser == null) {
      return const SizedBox.shrink();
    }

    List<String> details = [];
    if (_selectedFilter == 'Based on Skills') {
      details = currentUser.skills ?? [];
    } else if (_selectedFilter == 'Based on Experience') {
      if (currentUser.experience != null && currentUser.experience!.isNotEmpty) {
        details = [currentUser.experience!];
      }
    }

    if (details.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Text(
          'Add your ${_selectedFilter == 'Based on Skills' ? 'skills' : 'experience'} to your profile to get better recommendations.',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children: details
            .map((detail) => Chip(
                  label: Text(detail),
                  backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                  labelStyle: const TextStyle(color: Color(0xFF6C63FF)),
                  side: BorderSide.none,
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    return FutureBuilder<UserModel?>(
      future: _fetchCurrentUser(userId),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final currentUser = userSnapshot.data;
        final userSkills = currentUser?.skills ?? [];
        final userExperience = currentUser?.experience ?? '';

        final isFilterActive = _selectedFilter != 'All';
        final activeFilterWidget = _buildActiveFilterDetails(currentUser);

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              snap: false,
              backgroundColor: Colors.white,
              title: const Text(
                'Recommended Jobs',
                style: TextStyle(
                  color: Color(0xFF6C63FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(50.0),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Based on Skills'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Based on Experience'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (isFilterActive)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: activeFilterWidget,
                ),
              ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: Text(
                  'Best Matches for You',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('jobs').snapshots(),
              builder: (context, jobSnapshot) {
                if (jobSnapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: Center(child: Text('Error: ${jobSnapshot.error}')),
                  );
                }
                if (jobSnapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Center(child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    )),
                  );
                }
                if (!jobSnapshot.hasData || jobSnapshot.data!.docs.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Center(child: Text('No recommended jobs found.')),
                  );
                }

                final jobDocs = jobSnapshot.data!.docs;

                List<Job> jobs = [];
                for (var doc in jobDocs) {
                  try {
                    jobs.add(Job.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>));
                  } catch (e) {
                    // Optionally log error for the job that failed to parse
                  }
                }

                // Apply filtering and sorting logic
                if (_selectedFilter == 'Based on Skills') {
                  jobs.sort((a, b) {
                    final matchA = _calculateMatchPercentage(userSkills, a.skills);
                    final matchB = _calculateMatchPercentage(userSkills, b.skills);
                    return matchB.compareTo(matchA);
                  });
                } else if (_selectedFilter == 'Based on Experience') {
                  jobs.sort((a, b) {
                    // Basic sort: jobs matching user experience first
                    final matchA = (a.experience.toLowerCase() == userExperience.toLowerCase()) ? 1 : 0;
                    final matchB = (b.experience.toLowerCase() == userExperience.toLowerCase()) ? 1 : 0;
                    return matchB.compareTo(matchA);
                  });
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final job = jobs[index];
                      final isSaved = _savedJobIds.contains(job.id);
                      final matchPercentage = _calculateMatchPercentage(userSkills, job.skills);

                      return JobCard(
                        job: job,
                        isSaved: isSaved,
                        matchPercentage: matchPercentage,
                        onSave: () => _toggleSaveJob(job),
                        onTap: () => _navigateToDetail(job),
                        onApply: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => JobApplicationScreen(job: job.toJson()),
                            ),
                          );
                        },
                      );
                    },
                    childCount: jobs.length,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String title) {
    bool isSelected = _selectedFilter == title;
    return ChoiceChip(
      label: Text(title),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = title;
          });
        }
      },
      backgroundColor: Colors.grey[200],
      selectedColor: const Color(0xFF6C63FF).withValues(alpha: 0.9),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(
          color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[300]!,
        ),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
    );
  }
}

class JobCard extends StatelessWidget {
  final Job job;
  final bool isSaved;
  final int matchPercentage;
  final VoidCallback onSave;
  final VoidCallback onTap;
  final VoidCallback onApply;

  const JobCard({
    super.key,
    required this.job,
    required this.isSaved,
    required this.matchPercentage,
    required this.onSave,
    required this.onTap,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2.0,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        color: const Color(0xFFF8F7FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5C54A4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          job.company,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: isSaved ? const Color(0xFF6C63FF) : Colors.grey,
                    ),
                    onPressed: onSave,
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      job.location,
                      style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attach_money_outlined, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(
                    job.salary,
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (matchPercentage > 0)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$matchPercentage% Match',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: matchPercentage / 100,
                              backgroundColor: Colors.green.withValues(alpha: 0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: onApply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Apply Now', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
