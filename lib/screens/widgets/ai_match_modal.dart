import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../theme/app_theme.dart';

/// Bottom sheet hasil Skill Gap Analyzer.
/// Response: {score, matched_skills[], missing_skills[], summary, recommendations[]}
class AiMatchModal extends StatelessWidget {
  final Future<Map<String, dynamic>> future;
  const AiMatchModal({super.key, required this.future});

  static Future<void> show(
    BuildContext context,
    Future<Map<String, dynamic>> future,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AiMatchModal(future: future),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return FutureBuilder<Map<String, dynamic>>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const _Loading();
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Gagal menganalisis:\n${snap.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final d =
                (snap.data!['data'] ?? snap.data!) as Map<String, dynamic>;
            final score = ((d['score'] ?? 0) as num).toInt().clamp(0, 100);
            final matched = List<String>.from(
              (d['matched_skills'] ?? []).map((e) => '$e'),
            );
            final missing = List<String>.from(
              (d['missing_skills'] ?? []).map((e) => '$e'),
            );
            final recs = List<String>.from(
              (d['recommendations'] ?? []).map((e) => '$e'),
            );

            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'AI Skill Gap Analysis',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                Center(
                  child: CircularPercentIndicator(
                    radius: 62,
                    lineWidth: 12,
                    percent: score / 100,
                    animation: true,
                    circularStrokeCap: CircularStrokeCap.round,
                    progressColor: score >= 70
                        ? AppColors.success
                        : (score >= 40 ? AppColors.warning : AppColors.danger),
                    backgroundColor: AppColors.border,
                    center: Text(
                      '$score%',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _Section(
                  title: 'Skill yang Cocok',
                  child: _Chips(
                    items: matched,
                    color: AppColors.success,
                    empty: 'Belum ada yang cocok',
                  ),
                ),
                _Section(
                  title: 'Skill yang Kurang',
                  child: _Chips(
                    items: missing,
                    color: AppColors.danger,
                    empty: 'Tidak ada gap!',
                  ),
                ),
                _Section(
                  title: 'Ringkasan AI',
                  child: Text(
                    '${d['summary'] ?? '-'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (recs.isNotEmpty)
                  _Section(
                    title: 'Rekomendasi Belajar',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: recs
                          .map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.lightbulb_outline,
                                    size: 18,
                                    color: AppColors.accentDark,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(r)),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('AI sedang menganalisis skill Anda...'),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _Chips extends StatelessWidget {
  final List<String> items;
  final Color color;
  final String empty;
  const _Chips({required this.items, required this.color, required this.empty});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty)
      return Text(empty, style: Theme.of(context).textTheme.bodySmall);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                s,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
