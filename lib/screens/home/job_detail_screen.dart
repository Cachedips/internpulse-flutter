import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/job_model.dart';
import '../../providers/job_provider.dart';
import '../../providers/tracker_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/ai_match_modal.dart';
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
      appBar: AppBar(title: const Text('Detail Magang')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(job.jobTitle, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(job.companyName, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
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
            const SizedBox(height: 8),
            Text(
              'Kisaran: ${job.salaryRange}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 20),

          // ---- AI Skill Gap ----
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.accentDark),
                    const SizedBox(width: 8),
                    Text(
                      'Seberapa cocok skill saya?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'AI membandingkan keahlian di profil Anda dengan syarat lowongan ini.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Analisis Skill Gap'),
                  onPressed: () {
                    final future = context.read<JobProvider>().analyze(job);
                    AiMatchModal.show(context, future);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('Persyaratan', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            job.requirements.isEmpty
                ? 'Tidak ada detail persyaratan.'
                : job.requirements,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 28),

          OutlinedButton.icon(
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Simpan ke Tracker'),
            onPressed: () => _save(context),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Lamar Sekarang'),
            onPressed: () => _apply(context),
          ),
        ],
      ),
    );
  }
}
