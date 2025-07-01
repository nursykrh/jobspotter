import '../models/job.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JobService {
  static final _firestore = FirebaseFirestore.instance;
  static final _jobsCollection = _firestore.collection('jobs');

  // Add a new job
  static Future<void> createJob(Job job, String employerEmail) async {
    await _jobsCollection.doc(job.id).set({
      ...job.toJson(),
      'employerEmail': employerEmail,
    });
  }

  // Get jobs by employer
  static Future<List<Job>> getJobsByEmployer(String employerEmail) async {
    final snapshot = await _jobsCollection
        .where('employerEmail', isEqualTo: employerEmail)
        .get();

    return snapshot.docs
        .map((doc) => Job.fromJson(doc.data()))
        .toList();
  }

  // Update a job
  static Future<void> updateJob(Job job) async {
    await _jobsCollection.doc(job.id).update(job.toJson());
  }

  // Delete a job
  static Future<void> deleteJob(String jobId) async {
    await _jobsCollection.doc(jobId).delete();
  }

  // (Optional) Get a single job by ID
  static Future<Job?> getJobById(String jobId) async {
    final doc = await _jobsCollection.doc(jobId).get();
    if (doc.exists) {
      return Job.fromJson(doc.data()!);
    }
    return null;
  }

  // Get recent jobs for the dashboard
  static Future<List<Job>> getRecentJobs({int limit = 5}) async {
    final snapshot = await _jobsCollection
        .orderBy('postedDate', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => Job.fromJson(doc.data())).toList();
  }

  // Sample jobs (for demo only)
  static List<Job> getSampleJobs() {
    return [
      Job(
        id: '1',
        title: 'Senior Flutter Developer',
        company: 'Google',
        location: 'Mountain View, CA',
        description:
            'Join our team to build next-generation mobile applications using Flutter.',
        salary: '\$120,000 - \$180,000',
        skills: ['Flutter', 'Dart', 'Firebase', 'REST APIs'],
        companyLogo: 'assets/images/google_logo.png',
        matchPercentage: 95,
        employmentType: 'Full-time',
        experience: '5+ years',
        postedDate: DateTime.now().subtract(const Duration(days: 2)),
        employerEmail: 'hr@google.com',
        employerId: 'google_employer_id',
      ),
      Job(
        id: '2',
        title: 'Software Engineer',
        company: 'Microsoft',
        location: 'Redmond, WA',
        description:
            'Work on cutting-edge cloud technologies and enterprise solutions.',
        salary: '\$110,000 - \$170,000',
        skills: ['C#', '.NET', 'Azure', 'Microservices'],
        companyLogo: 'assets/images/microsoft_logo.png',
        matchPercentage: 88,
        employmentType: 'Full-time',
        experience: '3+ years',
        postedDate: DateTime.now().subtract(const Duration(days: 5)),
        employerEmail: 'hr@microsoft.com',
        employerId: 'microsoft_employer_id',
      ),
      Job(
        id: '3',
        title: 'Mobile App Developer',
        company: 'Meta',
        location: 'Menlo Park, CA',
        description:
            'Build and maintain high-performance mobile applications for Meta platforms.',
        salary: '\$130,000 - \$190,000',
        skills: ['React Native', 'JavaScript', 'GraphQL', 'Mobile Development'],
        companyLogo: 'assets/images/meta_logo.png',
        matchPercentage: 92,
        employmentType: 'Full-time',
        experience: '4+ years',
        postedDate: DateTime.now().subtract(const Duration(days: 1)),
        employerEmail: 'hr@meta.com',
        employerId: 'meta_employer_id',
      ),
      Job(
        id: '4',
        title: 'Flutter Developer',
        company: 'Amazon',
        location: 'Seattle, WA',
        description:
            'Develop cross-platform mobile applications using Flutter framework.',
        salary: '\$115,000 - \$175,000',
        skills: ['Flutter', 'Dart', 'AWS', 'Mobile Development'],
        companyLogo: 'assets/images/amazon_logo.png',
        matchPercentage: 90,
        employmentType: 'Contract',
        experience: '3+ years',
        postedDate: DateTime.now().subtract(const Duration(days: 3)),
        employerEmail: 'hr@amazon.com',
        employerId: 'amazon_employer_id',
      ),
      Job(
        id: '5',
        title: 'Senior Mobile Engineer',
        company: 'Apple',
        location: 'Cupertino, CA',
        description:
            'Create innovative mobile experiences for Apple platforms.',
        salary: '\$140,000 - \$200,000',
        skills: ['iOS', 'Swift', 'Flutter', 'Mobile Architecture'],
        companyLogo: 'assets/images/apple_logo.png',
        matchPercentage: 85,
        employmentType: 'Full-time',
        experience: '6+ years',
        postedDate: DateTime.now().subtract(const Duration(days: 7)),
        employerEmail: 'hr@apple.com',
        employerId: 'apple_employer_id',
      ),
    ];
  }
}
