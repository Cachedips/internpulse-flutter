import 'package:flutter/foundation.dart';

import '../models/job_model.dart';
import '../models/tracker_model.dart';
import '../services/api_service.dart';

class TrackerProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<TrackerModel> _items = [];
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? _insight;
  bool _insightLoading = false;
  String? _insightError;

  List<TrackerModel> get items => _items;
  bool get loading => _loading;
  String? get error => _error;
  Map<String, dynamic>? get insight => _insight;
  bool get insightLoading => _insightLoading;
  String? get insightError => _insightError;

  List<TrackerModel> byStatus(String status) =>
      _items.where((t) => t.status == status).toList();

  int count(String status) => _items.where((t) => t.status == status).length;

  /// Conversion rate lokal: (interview + diterima) / semua lamaran yang sudah dikirim.
  double get conversionRate {
    final sent = count('applied') + count('interview') + count('accepted') + count('rejected');
    if (sent == 0) return 0;
    return (count('interview') + count('accepted')) / sent * 100;
  }

  void reset() {
    _items = [];
    _insight = null;
    _error = null;
    _insightError = null;
    notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.getTrackers();
      final list = (res['data'] as List?) ?? [];
      _items = list.map((e) => TrackerModel.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Simpan / lamar lowongan ke tracker. Mengembalikan pesan error (null = sukses).
  Future<String?> addFromJob(JobModel job, {String status = 'saved'}) async {
    try {
      await _api.createTracker(job.toTrackerPayload(status: status));
      await load();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> moveTo(TrackerModel t, String status) async {
    try {
      final res = await _api.updateTrackerStatus(t.id, status);
      final data = res['data'];
      if (data is Map<String, dynamic>) {
        _replace(TrackerModel.fromJson(data));
      } else {
        await load();
      }
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> remove(TrackerModel t) async {
    try {
      await _api.deleteTracker(t.id);
      _items.removeWhere((x) => x.id == t.id);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  void _replace(TrackerModel updated) {
    final i = _items.indexWhere((x) => x.id == updated.id);
    if (i >= 0) _items[i] = updated;
    notifyListeners();
  }

  // ----------------------------- AI FEATURES --------------------------------
  /// [AI 1] Career insight
  Future<void> loadInsight() async {
    _insightLoading = true;
    _insightError = null;
    notifyListeners();
    try {
      final res = await _api.getCareerInsight();
      _insight = (res['data'] ?? res) as Map<String, dynamic>;
    } on ApiException catch (e) {
      _insightError = e.message;
    } finally {
      _insightLoading = false;
      notifyListeners();
    }
  }

  /// [AI 2] Follow-up email. Melempar ApiException jika gagal.
  Future<String> generateFollowUp(TrackerModel t, String type) async {
    final res = await _api.generateFollowUp(t.id, type: type);
    return (res['email'] ?? res['message'] ?? '') as String;
  }

  /// [AI 3] Interview simulator
  Future<String> nextInterviewQuestion(TrackerModel t) async {
    final res = await _api.startInterview(t.id);
    return (res['question'] ?? '') as String;
  }

  Future<Map<String, dynamic>> submitInterviewAnswer(
      TrackerModel t, String question, String answer) {
    return _api.submitInterviewAnswer(trackerId: t.id, question: question, answer: answer);
  }

  /// [AI 4] PDF
  Future<String> getReportPdfUrl() => _api.getReportPdfUrl();
}
