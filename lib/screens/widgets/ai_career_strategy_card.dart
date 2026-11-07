import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/tracker_provider.dart';
import '../../theme/app_theme.dart';

/// Widget dashboard di atas Kanban: statistik + strategi karir dari Gemini.
/// Response insight: {strategy: String, recommendations: [String]}
class AiCareerStrategyCard extends StatelessWidget {
  const AiCareerStrategyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackerProvider>(
      builder: (context, tp, _) {
        final insight = tp.insight;
        final recs = List<String>.from((insight?['recommendations'] ?? []).map((e) => '$e'));

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Text('AI Career Insight',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Stat(label: 'Total', value: '${tp.items.length}'),
                  _Stat(label: 'Dilamar', value: '${tp.count('applied')}'),
                  _Stat(label: 'Interview', value: '${tp.count('interview')}'),
                  _Stat(label: 'Diterima', value: '${tp.count('accepted')}'),
                  _Stat(label: 'Konversi', value: '${tp.conversionRate.toStringAsFixed(0)}%'),
                ],
              ),
              const SizedBox(height: 14),
              if (tp.insightLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
              else if (insight == null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.textPrimary,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    icon: const Icon(Icons.psychology_alt_outlined),
                    label: const Text('Analisis Strategi Karir'),
                    onPressed: tp.items.isEmpty ? null : tp.loadInsight,
                  ),
                )
              else ...[
                Text('${insight['strategy'] ?? ''}',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, height: 1.5)),
                if (recs.isNotEmpty) const SizedBox(height: 10),
                ...recs.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: AppColors.accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(r,
                                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                          ),
                        ],
                      ),
                    )),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: tp.loadInsight,
                    child: const Text('Perbarui analisis'),
                  ),
                ),
              ],
              if (tp.insightError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(tp.insightError!,
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
        ],
      );
}
