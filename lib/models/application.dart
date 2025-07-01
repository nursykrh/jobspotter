import 'package:cloud_firestore/cloud_firestore.dart';

class Application {
  final String id;
  final String jobId;
  final String jobseekerEmail;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime appliedAt;
  final String jobTitle;
  final String company;
  final String? coverLetter;
  final String? experience;
  final String? education;
  final List<String>? skills;

  Application({
    required this.id,
    required this.jobId,
    required this.jobseekerEmail,
    required this.status,
    required this.appliedAt,
    required this.jobTitle,
    required this.company,
    this.coverLetter,
    this.experience,
    this.education,
    this.skills,
  });

  factory Application.fromJson(Map<String, dynamic> json, String id) {
    // Support both jobseekerEmail and email, and both appliedAt and appliedDate
    final appliedAtRaw = json['appliedAt'] ?? json['appliedDate'];
    DateTime appliedAt;
    if (appliedAtRaw is Timestamp) {
      appliedAt = appliedAtRaw.toDate();
    } else if (appliedAtRaw is String) {
      appliedAt = DateTime.tryParse(appliedAtRaw) ?? DateTime.now();
    } else {
      appliedAt = DateTime.now();
    }
    List<String>? skillsList;
    if (json['skills'] is List) {
      skillsList = List<String>.from(json['skills']);
    } else if (json['skills'] is String) {
      skillsList = json['skills'].split(',').map((e) => e.trim()).toList();
    }
    return Application(
      id: id,
      jobId: json['jobId'] ?? '',
      jobseekerEmail: json['jobseekerEmail'] ?? json['email'] ?? '',
      status: json['status'] ?? '',
      appliedAt: appliedAt,
      jobTitle: json['jobTitle'] ?? '',
      company: json['company'] ?? '',
      coverLetter: json['coverLetter'],
      experience: json['experience'],
      education: json['education'],
      skills: skillsList,
    );
  }

  Map<String, dynamic> toJson() => {
    'jobId': jobId,
    'jobseekerEmail': jobseekerEmail,
    'status': status,
    'appliedAt': appliedAt,
    'jobTitle': jobTitle,
    'company': company,
    if (coverLetter != null) 'coverLetter': coverLetter,
    if (experience != null) 'experience': experience,
    if (education != null) 'education': education,
    if (skills != null) 'skills': skills,
  };
}
