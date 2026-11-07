import 'package:flutter/foundation.dart';

import '../models/job_model.dart';
import '../services/api_service.dart';

class JobProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<JobModel> _jobs = [];
  bool _loading = false;
  String? _error;

  String? _location; // null = semua
  String? _major; // null = semua
  String _search = '';

  List<JobModel> get jobs => _jobs;
  bool get loading => _loading;
  String? get error => _error;
  String? get location => _location;
  String? get major => _major;
  String get search => _search;

  Future<void> fetchJobs() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.getJobs(location: _location, major: _major, search: _search);
      final list = (res['data'] as List?) ?? [];
      _jobs = list.map((e) => JobModel.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setLocation(String? value) {
    _location = (value == _location) ? null : value; // tap lagi = hapus filter
    fetchJobs();
  }

  void setMajor(String? value) {
    _major = value;
    fetchJobs();
  }

  void setSearch(String value) {
    _search = value.trim();
    fetchJobs();
  }

  /// Skill Gap Analyzer. Skill user diambil backend dari akun yang login.
  Future<Map<String, dynamic>> analyze(JobModel job) {
    return _api.analyzeSkillGap(jobTitle: job.jobTitle, jobRequirements: job.requirements);
  }
}
