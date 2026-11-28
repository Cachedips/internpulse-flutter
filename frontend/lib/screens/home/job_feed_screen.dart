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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Lowongan Magang')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            children: [
              // ---------- Filter & Search Container ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
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
                      TextField(
                        controller: _searchCtrl,
                        textInputAction: TextInputAction.search,
                        onSubmitted: jp.setSearch,
                        decoration: InputDecoration(
                          hintText: 'Cari posisi, keahlian, atau perusahaan...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.textSecondary,
                          ),
                          suffixIcon: _searchCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    jp.setSearch('');
                                  },
                                ),
                          fillColor: const Color(0xFFF8FAFC),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.accentDark,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 720;
                          final filterChips = SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final loc in kLocations)
                                  Builder(
                                    builder: (context) {
                                      final isSelected =
                                          (loc == 'Semua' &&
                                              jp.location == null) ||
                                          jp.location == loc;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: FilterChip(
                                          label: Text(loc),
                                          selected: isSelected,
                                          selectedColor: AppColors.primary
                                              .withValues(alpha: 0.12),
                                          checkmarkColor: AppColors.primary,
                                          labelStyle: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                          ),
                                          onSelected: (_) =>
                                              jp.setLocation(loc),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          );

                          final majorDropdown = SizedBox(
                            width: isWide ? 260 : double.infinity,
                            child: DropdownButtonFormField<String?>(
                              initialValue: jp.major,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Filter Jurusan',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Semua jurusan'),
                                ),
                                ...kMajors.map(
                                  (m) => DropdownMenuItem<String?>(
                                    value: m,
                                    child: Text(m),
                                  ),
                                ),
                              ],
                              onChanged: jp.setMajor,
                            ),
                          );

                          if (isWide) {
                            return Row(
                              children: [
                                Expanded(child: filterChips),
                                const SizedBox(width: 16),
                                majorDropdown,
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              filterChips,
                              const SizedBox(height: 8),
                              majorDropdown,
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ---------- Job Feed Body ----------
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildBody(jp),
                ),
              ),
            ],
          ),
        ),
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
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
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
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: jp.fetchJobs,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (jp.jobs.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Tidak ada lowongan ditemukan.',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Coba ubah kata kunci pencarian atau sesuaikan filter lokasi/jurusan.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: jp.fetchJobs,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          int crossAxisCount = 1;
          if (width >= 960) {
            crossAxisCount = 3;
          } else if (width >= 620) {
            crossAxisCount = 2;
          }

          if (crossAxisCount == 1) {
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: jp.jobs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (_, i) => _JobCard(job: jp.jobs[i]),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 185,
            ),
            itemCount: jp.jobs.length,
            itemBuilder: (_, i) => _JobCard(job: jp.jobs[i]),
          );
        },
      ),
    );
  }
}

class _JobCard extends StatefulWidget {
  final JobModel job;
  const _JobCard({required this.job});

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? AppColors.accentDark : AppColors.border,
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: _isHovered ? 14 : 8,
              offset: Offset(0, _isHovered ? 5 : 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => JobDetailScreen(job: widget.job)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.job.jobTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: _isHovered
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StipendBadge(type: widget.job.stipendType),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.business_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.job.companyName,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _Meta(
                      icon: Icons.location_on_outlined,
                      text: widget.job.location,
                      isLocation: true,
                    ),
                    if (widget.job.majorCategory != null)
                      _Meta(
                        icon: Icons.school_outlined,
                        text: widget.job.majorCategory!,
                      ),
                    if (widget.job.isLocal)
                      const _Meta(icon: Icons.verified_outlined, text: 'Lokal'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isLocation;
  const _Meta({
    required this.icon,
    required this.text,
    this.isLocation = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: isLocation ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(6),
      border: isLocation ? Border.all(color: const Color(0xFFBFDBFE)) : null,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: isLocation ? const Color(0xFF2563EB) : AppColors.accentDark,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isLocation ? FontWeight.w600 : FontWeight.w500,
            color: isLocation
                ? const Color(0xFF1E40AF)
                : AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}
