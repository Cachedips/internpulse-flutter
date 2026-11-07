import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/job_model.dart';
import '../../providers/job_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/stipend_badge.dart';
import 'job_detail_screen.dart';

class JobFeedScreen extends StatefulWidget {
  const JobFeedScreen({super.key});

  @override
  State<JobFeedScreen> createState() => _JobFeedScreenState();
}

class _JobFeedScreenState extends State<JobFeedScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JobProvider>().fetchJobs();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jp = context.watch<JobProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Lowongan Magang')),
      body: Column(
        children: [
          // ---------- Search + filter ----------
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: jp.setSearch,
              decoration: InputDecoration(
                hintText: 'Cari posisi atau perusahaan...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchCtrl.clear();
                          jp.setSearch('');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final loc in kLocations)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(loc),
                      selected: jp.location == loc,
                      onSelected: (_) => jp.setLocation(loc),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: DropdownButtonFormField<String?>(
              initialValue: jp.major,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Filter Jurusan',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Semua jurusan'),
                ),
                ...kMajors.map(
                  (m) => DropdownMenuItem<String?>(value: m, child: Text(m)),
                ),
              ],
              onChanged: jp.setMajor,
            ),
          ),

          // ---------- List ----------
          Expanded(child: _buildBody(jp)),
        ],
      ),
    );
  }

  Widget _buildBody(JobProvider jp) {
    if (jp.loading && jp.jobs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (jp.error != null && jp.jobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(jp.error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(140, 44),
                ),
                onPressed: jp.fetchJobs,
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }
    if (jp.jobs.isEmpty) {
      return const Center(child: Text('Tidak ada lowongan ditemukan.'));
    }

    return RefreshIndicator(
      onRefresh: jp.fetchJobs,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: jp.jobs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _JobCard(job: jp.jobs[i]),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final JobModel job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.jobTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  StipendBadge(type: job.stipendType),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                job.companyName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _Meta(icon: Icons.place_outlined, text: job.location),
                  if (job.majorCategory != null)
                    _Meta(
                      icon: Icons.school_outlined,
                      text: job.majorCategory!,
                    ),
                  if (job.isLocal)
                    const _Meta(
                      icon: Icons.verified_outlined,
                      text: 'Lowongan Lokal',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppColors.accentDark),
      const SizedBox(width: 4),
      Text(text, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
