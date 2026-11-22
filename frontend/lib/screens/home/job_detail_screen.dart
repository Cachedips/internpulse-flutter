import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/job_model.dart';
import '../../providers/tracker_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/stipend_badge.dart';

class JobDetailScreen extends StatelessWidget {
  final JobModel job;
  const JobDetailScreen({super.key, required this.job});

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save(BuildContext context, {String status = 'saved'}) async {
    final err = await context.read<TrackerProvider>().addFromJob(
      job,
      status: status,
    );
    if (!context.mounted) return;
    _snack(
      context,
      err ??
          (status == 'saved'
              ? 'Disimpan ke tracker'
              : 'Ditambahkan sebagai "Dilamar"'),
    );
  }

  Future<void> _apply(BuildContext context) async {
    final url = job.jobUrl;
    if (url == null || url.isEmpty) {
      _snack(context, 'Link lamaran tidak tersedia');
      return;
    }
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!context.mounted) return;
    if (ok) {
      await _save(context, status: 'applied');
    } else {
      _snack(context, 'Tidak bisa membuka link');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Detail Magang')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.jobTitle,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.business_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          job.companyName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StipendBadge(type: job.stipendType),
                        Chip(
                          avatar: const Icon(Icons.place_outlined, size: 16),
                          label: Text(job.location),
                        ),
                        if (job.majorCategory != null)
                          Chip(
                            avatar: const Icon(Icons.school_outlined, size: 16),
                            label: Text(job.majorCategory!),
                          ),
                      ],
                    ),
                    if (job.salaryRange != null && job.salaryRange!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.payments_outlined, size: 16, color: AppColors.accentDark),
                          const SizedBox(width: 6),
                          Text(
                            'Kisaran: ${job.salaryRange}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ---- AI Skill Gap ----
              SmartMatchSkillGapPanel(job: job),
              const SizedBox(height: 20),

              // Requirements Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description_outlined, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Persyaratan & Deskripsi Pekerjaan',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      job.requirements.isEmpty
                          ? 'Tidak ada detail persyaratan.'
                          : job.requirements,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons (responsive row / column)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 600;
                  final saveBtn = OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Simpan ke Tracker'),
                    onPressed: () => _save(context),
                  );
                  final applyBtn = ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Lamar Sekarang'),
                    onPressed: () => _apply(context),
                  );

                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(child: saveBtn),
                        const SizedBox(width: 16),
                        Expanded(child: applyBtn),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      saveBtn,
                      const SizedBox(height: 12),
                      applyBtn,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Panel Smart Match & Skill Gap (Fitur 2):
/// Membandingkan keahlian profil dengan lowongan via AI,
/// menampilkan match_percentage, matched_skills (hijau),
/// missing_skills (oranye/merah), dan recommendation AI.
class SmartMatchSkillGapPanel extends StatefulWidget {
  final JobModel job;
  const SmartMatchSkillGapPanel({super.key, required this.job});

  @override
  State<SmartMatchSkillGapPanel> createState() => _SmartMatchSkillGapPanelState();
}

class _SmartMatchSkillGapPanelState extends State<SmartMatchSkillGapPanel> {
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService().skillGap(
        jobTitle: widget.job.jobTitle,
        jobDescription: widget.job.requirements.isNotEmpty
            ? widget.job.requirements
            : widget.job.jobTitle,
      );
      setState(() {
        _result = res['data'] is Map<String, dynamic>
            ? res['data'] as Map<String, dynamic>
            : res;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Gagal menganalisis skill gap: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accentDark.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.accentDark, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Match & Skill Gap',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'Bandingkan keahlian profil dengan lowongan ini via AI',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Loading state
          if (_loading) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Gemini AI sedang menganalisis kesesuaian skill Anda...',
                      style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade900,
                      side: BorderSide(color: Colors.red.shade300),
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Coba Lagi'),
                    onPressed: _analyze,
                  ),
                ],
              ),
            ),
          ] else if (_result == null) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Analisis Kecocokan Skill'),
              onPressed: _analyze,
            ),
          ] else ...[
            _buildResultContent(context),
          ],
        ],
      ),
    );
  }

  Widget _buildResultContent(BuildContext context) {
    final matchPercentage = (_result!['match_percentage'] as num?)?.toInt() ?? 0;
    final matchedList = ((_result!['matched_skills'] as List?) ?? [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final missingList = ((_result!['missing_skills'] as List?) ?? [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final recommendation = (_result!['recommendation'] as String?)?.trim() ?? '';

    final isHigh = matchPercentage >= 70;
    final isMedium = matchPercentage >= 40 && matchPercentage < 70;
    final matchColor = isHigh
        ? Colors.green.shade700
        : (isMedium ? Colors.orange.shade800 : Colors.red.shade700);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Percentage Match Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: matchColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: matchColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$matchPercentage%',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: matchColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tingkat Kecocokan: $matchPercentage%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: matchColor,
                          ),
                        ),
                        Text(
                          isHigh
                              ? 'Kecocokan Tinggi! Sangat direkomendasikan melamar.'
                              : (isMedium
                                  ? 'Kecocokan Sedang. Ada beberapa skill tambahan yang dibutuhkan.'
                                  : 'Perlu peningkatan keahlian untuk posisi ini.'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: matchPercentage / 100.0,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(matchColor),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Matched Skills (Green Chips)
        Row(
          children: [
            Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade700),
            const SizedBox(width: 6),
            Text(
              'Skill yang Cocok (${matchedList.length})',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.green.shade900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (matchedList.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Belum ada keahlian di profil yang cocok dengan lowongan ini.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: matchedList
                  .map(
                    (s) => Chip(
                      avatar: const Icon(Icons.check, size: 14, color: Colors.green),
                      label: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      backgroundColor: Colors.green.shade50,
                      side: BorderSide(color: Colors.green.shade300),
                    ),
                  )
                  .toList(),
            ),
          ),
        const SizedBox(height: 8),

        // 3. Missing Skills (Orange/Red Chips)
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: Colors.deepOrange.shade700),
            const SizedBox(width: 6),
            Text(
              'Skill yang Perlu Dipelajari (${missingList.length})',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.deepOrange.shade900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (missingList.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Profil Anda telah mencakup seluruh kebutuhan lowongan!',
              style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w500),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: missingList
                  .map(
                    (s) => Chip(
                      avatar: const Icon(Icons.add_circle_outline, size: 14, color: Colors.deepOrange),
                      label: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      backgroundColor: Colors.deepOrange.shade50,
                      side: BorderSide(color: Colors.deepOrange.shade300),
                    ),
                  )
                  .toList(),
            ),
          ),
        const SizedBox(height: 8),

        // 4. Recommendation AI
        if (recommendation.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accentDark.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: AppColors.accentDark),
                    SizedBox(width: 6),
                    Text(
                      'Rekomendasi AI:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.accentDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  recommendation,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 5. Re-analyze button
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.refresh, size: 15),
            label: const Text('Analisis Ulang', style: TextStyle(fontSize: 12)),
            onPressed: _analyze,
          ),
        ),
      ],
    );
  }
}
