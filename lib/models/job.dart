import 'package:cloud_firestore/cloud_firestore.dart';

class Job {
  final String id;
  String title;
  String company;
  String location;
  String description;
  String salary;
  List<String> skills;
  String companyLogo;
  double matchPercentage;
  String employmentType;
  String experience;
  final DateTime postedDate;
  final String employerEmail;
  final String employerId;
  final double latitude;
  final double longitude;
  String category;
  String companyProfile;

  Job({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.description,
    required this.salary,
    required this.skills,
    required this.companyLogo,
    required this.matchPercentage,
    required this.employmentType,
    required this.experience,
    required this.postedDate,
    required this.employerEmail,
    required this.employerId,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.category = '-',
    this.companyProfile = '',
  });

  Job copyWith({
    String? id,
    String? title,
    String? company,
    String? location,
    String? description,
    String? salary,
    List<String>? skills,
    String? companyLogo,
    double? matchPercentage,
    String? employmentType,
    String? experience,
    DateTime? postedDate,
    String? employerEmail,
    String? employerId,
    double? latitude,
    double? longitude,
    String? category,
    String? companyProfile,
  }) {
    return Job(
      id: id ?? this.id,
      title: title ?? this.title,
      company: company ?? this.company,
      location: location ?? this.location,
      description: description ?? this.description,
      salary: salary ?? this.salary,
      skills: skills ?? this.skills,
      companyLogo: companyLogo ?? this.companyLogo,
      matchPercentage: matchPercentage ?? this.matchPercentage,
      employmentType: employmentType ?? this.employmentType,
      experience: experience ?? this.experience,
      postedDate: postedDate ?? this.postedDate,
      employerEmail: employerEmail ?? this.employerEmail,
      employerId: employerId ?? this.employerId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      companyProfile: companyProfile ?? this.companyProfile,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'company': company,
      'location': location,
      'description': description,
      'salary': salary,
      'skills': skills,
      'companyLogo': companyLogo,
      'matchPercentage': matchPercentage,
      'employmentType': employmentType,
      'experience': experience,
      'postedDate': Timestamp.fromDate(postedDate),
      'employerEmail': employerEmail,
      'employerId': employerId,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'companyProfile': companyProfile,
    };
  }

  factory Job.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    
    DateTime parsedDate;
    if (data['postedDate'] is String) {
      parsedDate = DateTime.parse(data['postedDate'] as String);
    } else if (data['postedDate'] is Timestamp) {
      parsedDate = (data['postedDate'] as Timestamp).toDate();
    } else {
      parsedDate = DateTime.now();
    }

    return Job(
      id: doc.id,
      title: data['title'] ?? '',
      company: data['company'] ?? '',
      location: data['location'] ?? '',
      description: data['description'] ?? '',
      salary: data['salary'] ?? '',
      skills: List<String>.from(data['skills'] ?? []),
      companyLogo: data['companyLogo'] ?? '',
      matchPercentage: (data['matchPercentage'] as num?)?.toDouble() ?? 0.0,
      employmentType: data['employmentType'] ?? '',
      experience: data['experience'] ?? '',
      postedDate: parsedDate,
      employerEmail: data['employerEmail'] ?? '',
      employerId: data['employerId'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] ?? '-',
      companyProfile: data['companyProfile'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'company': company,
      'location': location,
      'description': description,
      'salary': salary,
      'skills': skills,
      'companyLogo': companyLogo,
      'matchPercentage': matchPercentage,
      'employmentType': employmentType,
      'experience': experience,
      'postedDate': postedDate.toIso8601String(),
      'employerEmail': employerEmail,
      'employerId': employerId,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'companyProfile': companyProfile,
    };
  }

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] as String,
      title: json['title'] as String,
      company: json['company'] as String,
      location: json['location'] as String,
      description: json['description'] as String,
      salary: json['salary'] as String,
      skills: List<String>.from(json['skills']),
      companyLogo: json['companyLogo'] as String,
      matchPercentage: (json['matchPercentage'] as num).toDouble(),
      employmentType: json['employmentType'] as String,
      experience: json['experience'] as String,
      postedDate: json['postedDate'] is String
          ? DateTime.parse(json['postedDate'])
          : (json['postedDate'] as Timestamp).toDate(),
      employerEmail: json['employerEmail'] ?? '',
      employerId: json['employerId'] ?? '',
      latitude: (json['latitude'] ?? 0.0) is int ? (json['latitude'] ?? 0.0).toDouble() : (json['latitude'] ?? 0.0),
      longitude: (json['longitude'] ?? 0.0) is int ? (json['longitude'] ?? 0.0).toDouble() : (json['longitude'] ?? 0.0),
      category: json['category'] ?? '-',
      companyProfile: json['companyProfile'] ?? '',
    );
  }

  factory Job.fromMap(Map<String, dynamic> data) {
    DateTime parsedDate;
    if (data['postedDate'] is String) {
      parsedDate = DateTime.parse(data['postedDate'] as String);
    } else if (data['postedDate'] is Timestamp) {
      parsedDate = (data['postedDate'] as Timestamp).toDate();
    } else {
      parsedDate = DateTime.now();
    }

    return Job(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      company: data['company'] ?? '',
      location: data['location'] ?? '',
      description: data['description'] ?? '',
      salary: data['salary'] ?? '',
      skills: List<String>.from(data['skills'] ?? []),
      companyLogo: data['companyLogo'] ?? '',
      matchPercentage: (data['matchPercentage'] as num?)?.toDouble() ?? 0.0,
      employmentType: data['employmentType'] ?? '',
      experience: data['experience'] ?? '',
      postedDate: parsedDate,
      employerEmail: data['employerEmail'] ?? '',
      employerId: data['employerId'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] ?? '-',
      companyProfile: data['companyProfile'] ?? '',
    );
  }
}