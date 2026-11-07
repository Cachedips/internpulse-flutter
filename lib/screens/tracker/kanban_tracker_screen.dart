import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/tracker_model.dart';
import '../../providers/tracker_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/ai_career_strategy_card.dart';
import '../widgets/followup_email_modal.dart';
import '../widgets/stipend_badge.dart';
import 'interactive_interview_screen.dart';

const Map<String, Color> _statusColors = {
  'saved': AppColors.textSecondary,
  'applied': AppColors.accentDark,
  'interview': AppColors.warning,
  'accepted': AppColors.success,
  'rejected': AppColors.danger,
};

class KanbanTrackerScreen extends StatefulWidget {
  const KanbanTrackerScreen({super.key});

  @override
  State<KanbanTrackerScreen> createState() => _KanbanTrackerScreenState();
}

class _KanbanTrackerScreenState extends State<KanbanTrackerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrackerProvider>().load();
    });
  }

  // [AI 4] Cetak PDF 1-klik
  Future<void> _exportPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('AI sedang menyusun laporan PDF...')),
    );
    try {
      final url = await context.read<TrackerProvider>().getReportPdfUrl();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal membuat PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TrackerProvider>();

    return DefaultTabController(
      length: kStatuses.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tracker Lamaran'),
          actions: [
            IconButton(
              tooltip: 'Cetak Laporan PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: tp.items.isEmpty ? null : _exportPdf,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.accent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              for (final s in kStatuses)
                Tab(text: '${kStatusLabels[s]} (${tp.count(s)})'),
            ],
          ),
        ),
        body: tp.loading && tp.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : NestedScrollView(
                headerSliverBuilder: (_, _) => [
                  const SliverPadding(
                    padding: EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(child: AiCareerStrategyCard()),
                  ),
                ],
                body: TabBarView(
                  children: [
                    for (final s in kStatuses) _StatusColumn(status: s),
                  ],
                ),
              ),
      ),
    );
  }
}

class _StatusColumn extends StatelessWidget {
  final String status;
  const _StatusColumn({required this.status});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TrackerProvider>();
    final list = tp.byStatus(status);

    return RefreshIndicator(
      onRefresh: tp.load,
      child: list.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 60),
                Center(
                  child: Text(
                    tp.error ??
                        'Belum ada lamaran di "${kStatusLabels[status]}"',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _TrackerCard(tracker: list[i]),
            ),
    );
  }
}

class _TrackerCard extends StatelessWidget {
  final TrackerModel tracker;
  const _TrackerCard({required this.tracker});

  Future<void> _move(BuildContext context, String status) async {
    final err = await context.read<TrackerProvider>().moveTo(tracker, status);
    if (context.mounted && err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus lamaran?'),
        content: Text('${tracker.jobTitle} - ${tracker.companyName}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<TrackerProvider>().remove(tracker);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColors[tracker.status] ?? AppColors.textSecondary;
    final provider = context.read<TrackerProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tracker.jobTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        tracker.companyName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) =>
                      v == '_delete' ? _delete(context) : _move(context, v),
                  itemBuilder: (_) => [
                    for (final s in kStatuses)
                      if (s != tracker.status)
                        PopupMenuItem(
                          value: s,
                          child: Text('Pindah ke ${kStatusLabels[s]}'),
                        ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: '_delete', child: Text('Hapus')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StipendBadge(type: tracker.stipendType),
                Text(
                  tracker.location,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (tracker.aiMatchScore != null)
                  Text(
                    'Match ${tracker.aiMatchScore}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),

            // [AI 2] Follow-up
            if (tracker.needsFollowUp) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                ),
                icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
                label: Text('Follow-up (${tracker.daysSinceUpdate} hari)'),
                onPressed: () => FollowUpEmailModal.show(
                  context,
                  (type) => provider.generateFollowUp(tracker, type),
                ),
              ),
            ],

            // [AI 3] Interview simulator
            if (tracker.status == 'interview') ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  backgroundColor: AppColors.accentDark,
                ),
                icon: const Icon(Icons.record_voice_over_outlined, size: 18),
                label: const Text('Latihan Wawancara AI'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        InteractiveInterviewScreen(tracker: tracker),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
