import 'package:flutter/foundation.dart';
import '../models/job.dart';

class JobProvider with ChangeNotifier {
  List<Job> _jobs = [];
  final List<Job> _savedJobs = [];
  final List<Job> _appliedJobs = [];
  String _selectedFilter = 'All';

  List<Job> get jobs => _jobs;
  List<Job> get savedJobs => _savedJobs;
  List<Job> get appliedJobs => _appliedJobs;
  String get selectedFilter => _selectedFilter;

  void setJobs(List<Job> jobs) {
    _jobs = jobs;
    notifyListeners();
  }

  void addJob(Job job) {
    _jobs.add(job);
    notifyListeners();
  }

  void saveJob(Job job) {
    if (!_savedJobs.contains(job)) {
      _savedJobs.add(job);
      notifyListeners();
    }
  }

  void unsaveJob(Job job) {
    _savedJobs.remove(job);
    notifyListeners();
  }

  void applyToJob(Job job) {
    if (!_appliedJobs.contains(job)) {
      _appliedJobs.add(job);
      notifyListeners();
    }
  }

  void setSelectedFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  List<Job> getFilteredJobs() {
    if (_selectedFilter == 'All') {
      return _jobs;
    } else {
      return _jobs
          .where((job) =>
              job.employmentType == _selectedFilter ||
              job.matchPercentage >= 90 && _selectedFilter == 'Best Match' ||
              DateTime.now().difference(job.postedDate).inDays <= 7 &&
                  _selectedFilter == 'Recent')
          .toList();
    }
  }

  bool isJobSaved(Job job) {
    return _savedJobs.contains(job);
  }

  bool isJobApplied(Job job) {
    return _appliedJobs.contains(job);
  }
}
