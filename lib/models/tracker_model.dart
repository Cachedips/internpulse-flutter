import 'dart:convert';

/// Urutan kolom Kanban.
const List<String> kStatuses = ['saved', 'applied', 'interview', 'accepted', 'rejected'];

const Map<String, String> kStatusLabels = {
  'saved': 'Tersimpan',
  'applied': 'Dilamar',
  'interview': 'Interview',
  'accepted': 'Diterima',
  'rejected': 'Ditolak',
};

/// Tombol Follow-up muncul jika status 'applied' sudah lebih dari N hari.
/// (Set ke 0 saat testing/demo agar tombolnya langsung terlihat.)
const int kFollowUpDays = 7;

dynamic _decode(dynamic v) {
  if (v is String && v.trim().isNotEmpty) {
    try {
      return jsonDecode(v);
    } catch (_) {
      return null;
    }
  }
  return v;
}

class TrackerModel {
  final int id;
  final String companyName;
  final String jobTitle;
  final String location;
  final String? majorCategory;
  final String? jobUrl;
  final String jobRequirements;
  final String stipendType;
  final String status;
  final int? aiMatchScore;
  final Map<String, dynamic>? aiFeedback;
  final String? aiFollowupEmail;
  final List<dynamic> interviewLogs;
  final String? personalNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TrackerModel({
    required this.id,
    required this.companyName,
    required this.jobTitle,
    this.location = 'Remote',
    this.majorCategory,
    this.jobUrl,
    this.jobRequirements = '',
    this.stipendType = 'unknown',
    this.status = 'saved',
    this.aiMatchScore,
    this.aiFeedback,
    this.aiFollowupEmail,
    this.interviewLogs = const [],
    this.personalNotes,
    this.createdAt,
    this.updatedAt,
  });

  factory TrackerModel.fromJson(Map<String, dynamic> j) {
    final fb = _decode(j['ai_feedback']);
    final logs = _decode(j['interview_logs']);
    return TrackerModel(
      id: j['id'] as int,
      companyName: (j['company_name'] ?? '-') as String,
      jobTitle: (j['job_title'] ?? '-') as String,
      location: (j['location'] ?? 'Remote') as String,
      majorCategory: j['major_category'] as String?,
      jobUrl: j['job_url'] as String?,
      jobRequirements: (j['job_requirements'] ?? '') as String,
      stipendType: (j['stipend_type'] ?? 'unknown') as String,
      status: (j['status'] ?? 'saved') as String,
      aiMatchScore: j['ai_match_score'] as int?,
      aiFeedback: fb is Map<String, dynamic> ? fb : null,
      aiFollowupEmail: j['ai_followup_email'] as String?,
      interviewLogs: logs is List ? logs : const [],
      personalNotes: j['personal_notes'] as String?,
      createdAt: DateTime.tryParse('${j['created_at']}'),
      updatedAt: DateTime.tryParse('${j['updated_at']}'),
    );
  }

  /// Umur sejak status terakhir berubah (updated_at dipakai sebagai acuan).
  int get daysSinceUpdate {
    final ref = updatedAt ?? createdAt;
    if (ref == null) return 0;
    return DateTime.now().difference(ref).inDays;
  }

  bool get needsFollowUp => status == 'applied' && daysSinceUpdate >= kFollowUpDays;
}
