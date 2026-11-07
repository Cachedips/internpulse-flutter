const List<String> kLocations = ['Surabaya', 'Jakarta', 'Remote', 'Luar Negeri'];

const List<String> kMajors = [
  'Informatika/SI',
  'DKV',
  'Manajemen/Pemasaran',
  'Teknik Elektro',
  'Akuntansi/Keuangan',
  'Lainnya',
];

class JobModel {
  final String id; // mis. "remotive-123" atau "local-5"
  final String source; // 'remotive' | 'local'
  final String companyName;
  final String jobTitle;
  final String location;
  final String? majorCategory;
  final String stipendType; // paid | unpaid | allowance | unknown
  final String? salaryRange;
  final String requirements;
  final String? jobUrl;

  const JobModel({
    required this.id,
    required this.source,
    required this.companyName,
    required this.jobTitle,
    required this.location,
    this.majorCategory,
    this.stipendType = 'unknown',
    this.salaryRange,
    this.requirements = '',
    this.jobUrl,
  });

  bool get isLocal => source == 'local';

  factory JobModel.fromJson(Map<String, dynamic> j) => JobModel(
        id: '${j['id']}',
        source: (j['source'] ?? 'remotive') as String,
        companyName: (j['company_name'] ?? '-') as String,
        jobTitle: (j['job_title'] ?? '-') as String,
        location: (j['location'] ?? 'Remote') as String,
        majorCategory: j['major_category'] as String?,
        stipendType: (j['stipend_type'] ?? 'unknown') as String,
        salaryRange: j['salary_range'] as String?,
        requirements: (j['job_requirements'] ?? '') as String,
        jobUrl: (j['job_url'] ?? j['application_link']) as String?,
      );

  /// Payload untuk POST /trackers
  Map<String, dynamic> toTrackerPayload({String status = 'saved'}) => {
        'company_name': companyName,
        'job_title': jobTitle,
        'location': location,
        'major_category': majorCategory,
        'job_url': jobUrl,
        'job_requirements': requirements,
        'stipend_type': stipendType == 'allowance' ? 'paid' : stipendType,
        'status': status,
      };
}
