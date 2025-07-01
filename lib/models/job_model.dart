class JobModel {
  final String id;
  final String company;
  final String position;
  final String location;
  final String salary;
  final String description;
  final List<String> requirements;
  final List<String> skills;
  final String companyLogo;
  final DateTime postedDate;
  final bool isRemote;
  final String employmentType;
  final int matchPercentage;

  JobModel({
    required this.id,
    required this.company,
    required this.position,
    required this.location,
    required this.salary,
    required this.description,
    required this.requirements,
    required this.skills,
    required this.companyLogo,
    required this.postedDate,
    required this.isRemote,
    required this.employmentType,
    required this.matchPercentage,
  });

  // Create a copy of the current job with some fields updated
  JobModel copyWith({
    String? id,
    String? company,
    String? position,
    String? location,
    String? salary,
    String? description,
    List<String>? requirements,
    List<String>? skills,
    String? companyLogo,
    DateTime? postedDate,
    bool? isRemote,
    String? employmentType,
    int? matchPercentage,
  }) {
    return JobModel(
      id: id ?? this.id,
      company: company ?? this.company,
      position: position ?? this.position,
      location: location ?? this.location,
      salary: salary ?? this.salary,
      description: description ?? this.description,
      requirements: requirements ?? this.requirements,
      skills: skills ?? this.skills,
      companyLogo: companyLogo ?? this.companyLogo,
      postedDate: postedDate ?? this.postedDate,
      isRemote: isRemote ?? this.isRemote,
      employmentType: employmentType ?? this.employmentType,
      matchPercentage: matchPercentage ?? this.matchPercentage,
    );
  }
} 