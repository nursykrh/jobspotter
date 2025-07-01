import 'package:cloud_firestore/cloud_firestore.dart';

// Helper function to safely parse integer values that might be stored as strings
int? _safeParseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

class UserModel {
  // == Core Fields for Authentication & Role ==
  final String uid;
  final String email;
  final String role; // 'jobseeker' or 'employer'
  final Timestamp createdAt;

  // == Common Profile Fields ==
  String? name; // User's full name or company contact person name
  String? phone;
  String? location;
  String? profileImage; // URL to profile picture or company logo

  // == Job Seeker Specific Fields ==
  String? position;
  String? experience;
  String? education;
  String? languages;
  List<String>? skills;
  String? resumePath;
  final int appliedJobs;
  final int savedJobs;
  final int interviews;

  // == Employer Specific Fields ==
  String? companyName;
  String? verificationStatus; // 'pending', 'verified', 'rejected'
  String? ssmNumber;
  String? companyAddress;
  String? ssmDocumentUrl;
  String? companyDescription;
  String? website;
  String? industry;

  UserModel({
    // Core
    required this.uid,
    required this.email,
    required this.role,
    required this.createdAt,
    // Common
    this.name,
    this.phone,
    this.location,
    this.profileImage,
    // Job Seeker
    this.position,
    this.experience,
    this.education,
    this.languages,
    this.skills,
    this.resumePath,
    this.appliedJobs = 0,
    this.savedJobs = 0,
    this.interviews = 0,
    // Employer
    this.companyName,
    this.verificationStatus,
    this.ssmNumber,
    this.companyAddress,
    this.ssmDocumentUrl,
    this.companyDescription,
    this.website,
    this.industry,
  });

  // Factory to create UserModel from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'jobseeker',
      createdAt: map['createdAt'] is Timestamp ? map['createdAt'] : Timestamp.now(),
      // Handles both 'name' and older 'fullName' fields gracefully.
      name: map['name'] ?? map['fullName'],
      phone: map['phone'],
      location: map['location'],
      profileImage: map['profileImage'],
      position: map['position'],
      experience: map['experience'],
      education: map['education'],
      languages: map['languages'],
      skills: map['skills'] is List ? List<String>.from(map['skills']) : null,
      resumePath: map['resumePath'],
      // Safely parses integer fields, defaulting to 0 if null or invalid.
      appliedJobs: _safeParseInt(map['appliedJobs']) ?? 0,
      savedJobs: _safeParseInt(map['savedJobs']) ?? 0,
      interviews: _safeParseInt(map['interviews']) ?? 0,
      companyName: map['companyName'],
      verificationStatus: map['verificationStatus'],
      ssmNumber: map['ssmNumber'],
      companyAddress: map['companyAddress'],
      ssmDocumentUrl: map['ssmDocumentUrl'],
      companyDescription: map['companyDescription'],
      website: map['website'],
      industry: map['industry'],
    );
  }

  // Method to convert UserModel to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'createdAt': createdAt,
      'name': name,
      'phone': phone,
      'location': location,
      'profileImage': profileImage,
      'position': position,
      'experience': experience,
      'education': education,
      'languages': languages,
      'skills': skills,
      'resumePath': resumePath,
      'appliedJobs': appliedJobs,
      'savedJobs': savedJobs,
      'interviews': interviews,
      'companyName': companyName,
      'verificationStatus': verificationStatus,
      'ssmNumber': ssmNumber,
      'companyAddress': companyAddress,
      'ssmDocumentUrl': ssmDocumentUrl,
      'companyDescription': companyDescription,
      'website': website,
      'industry': industry,
    };
  }

  // Create a copy of the current user with some fields updated
  UserModel copyWith({
    String? uid,
    String? email,
    String? role,
    Timestamp? createdAt,
    String? name,
    String? phone,
    String? location,
    String? profileImage,
    String? position,
    String? experience,
    String? education,
    String? languages,
    List<String>? skills,
    String? resumePath,
    int? appliedJobs,
    int? savedJobs,
    int? interviews,
    String? companyName,
    String? verificationStatus,
    String? ssmNumber,
    String? companyAddress,
    String? ssmDocumentUrl,
    String? companyDescription,
    String? website,
    String? industry,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      profileImage: profileImage ?? this.profileImage,
      position: position ?? this.position,
      experience: experience ?? this.experience,
      education: education ?? this.education,
      languages: languages ?? this.languages,
      skills: skills ?? this.skills,
      resumePath: resumePath ?? this.resumePath,
      appliedJobs: appliedJobs ?? this.appliedJobs,
      savedJobs: savedJobs ?? this.savedJobs,
      interviews: interviews ?? this.interviews,
      companyName: companyName ?? this.companyName,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      ssmNumber: ssmNumber ?? this.ssmNumber,
      companyAddress: companyAddress ?? this.companyAddress,
      ssmDocumentUrl: ssmDocumentUrl ?? this.ssmDocumentUrl,
      companyDescription: companyDescription ?? this.companyDescription,
      website: website ?? this.website,
      industry: industry ?? this.industry,
    );
  }

  // Factory method to create a UserModel from a Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
    data['uid'] = doc.id; // Ensure the UID is set from the document ID
    return UserModel.fromMap(data);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'name': name,
      'phone': phone,
      'location': location,
      'profileImage': profileImage,
      'position': position,
      'experience': experience,
      'education': education,
      'languages': languages,
      'skills': skills,
      'resumePath': resumePath,
      'savedJobs': savedJobs,
      'interviews': interviews,
      'companyName': companyName,
      'verificationStatus': verificationStatus,
      'ssmNumber': ssmNumber,
      'companyAddress': companyAddress,
      'ssmDocumentUrl': ssmDocumentUrl,
      'companyDescription': companyDescription,
      'website': website,
      'industry': industry,
      'createdAt': createdAt,
    };
  }
} 