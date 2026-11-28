import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _marketTrends;
  List<Map<String, dynamic>> _skillScarcity = [];
  List<Map<String, dynamic>> _recommendations = [];

  String _selectedCategoryFilter = 'Semua';
  String? _lastSkillsSignature;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthService>().user;
    final signature = '${user?.major}_${(user?.skills ?? []).join(',')}';
    if (_lastSkillsSignature != null && _lastSkillsSignature != signature) {
      _lastSkillsSignature = signature;
      _loadData();
    } else {
      _lastSkillsSignature ??= signature;
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.marketTrends(),
        _api.skillScarcity(),
        _api.getJobRecommendations(),
      ]);

      final mtRes = results[0];
      final ssRes = results[1];
      final recRes = results[2];

      final mtData = mtRes['data'] is Map<String, dynamic>
          ? mtRes['data'] as Map<String, dynamic>
          : mtRes;

      final ssListRaw = ssRes['data'] is List
          ? ssRes['data'] as List
          : (ssRes['data'] is Map && ssRes['data']['data'] is List
                ? ssRes['data']['data'] as List
                : []);

      final ssList = ssListRaw.whereType<Map<String, dynamic>>().toList();

      List<Map<String, dynamic>> recList = [];
      if (recRes['data'] is List) {
        recList = (recRes['data'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      } else if (mtData['job_recommendations'] is List) {
        recList = (mtData['job_recommendations'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }

      if (!mounted) return;

      setState(() {
        _marketTrends = mtData;
        _skillScarcity = ssList;
        _recommendations = recList;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat analitik: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Market & Skill Analytics'),
        actions: [
          IconButton(
            tooltip: 'Segarkan data analitik',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Menghitung tren industri dan indeks kelangkaan skill...',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
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
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.danger,
                ),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        children: [
          _buildHeaderBanner(),
          const SizedBox(height: 24),
          _buildJobRecommendationsSection(),
          const SizedBox(height: 24),
          _buildKpiSummaryCards(),
          const SizedBox(height: 24),
          _buildTopSkillsSection(),
          const SizedBox(height: 24),
          _buildScarcityIndexSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard Analitik Pasar & Kebutuhan Skill',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Analisis real-time kebutuhan lowongan industri vs persaingan talenta agar strategi lamaran magang Anda lebih terarah.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobRecommendationsSection() {
    final user = context.watch<AuthService>().user;
    final userSkills = user?.skills ?? [];
    final userMajor = user?.major ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Rekomendasi Magang & Peluang Diterima',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Text(
                            'AI Smart Match',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userSkills.isNotEmpty
                          ? 'Disesuaikan dengan ${userSkills.length} keahlian CV dan jurusan ${userMajor.isNotEmpty ? userMajor : "Anda"}.'
                          : 'Rekomendasi posisi potensial berdasarkan profil Anda. Ekstrak CV di menu Profil untuk hasil lebih spesifik.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_recommendations.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.search_off_outlined,
                    size: 40,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Belum ada rekomendasi yang dihitung.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Unggah atau ekstrak CV Anda di tab Profil untuk mendapatkan analisis kecocokan lowongan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recommendations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (_, i) =>
                  _RecommendationCard(data: _recommendations[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryCards() {
    final totalJobs = (_marketTrends?['total_jobs'] as num?)?.toInt() ?? 0;

    final stipend =
        _marketTrends?['stipend_breakdown'] as Map<String, dynamic>?;
    final paidCount = (stipend?['paid'] as num?)?.toInt() ?? 0;
    final unpaidCount = (stipend?['unpaid'] as num?)?.toInt() ?? 0;
    final paidPercentage = totalJobs > 0
        ? ((paidCount / totalJobs) * 100).round()
        : 0;

    final location =
        _marketTrends?['location_breakdown'] as Map<String, dynamic>?;
    final remoteCount = (location?['remote'] as num?)?.toInt() ?? 0;
    final onsiteHybridCount =
        (location?['onsite_hybrid'] as num?)?.toInt() ?? 0;
    final remotePercentage = totalJobs > 0
        ? ((remoteCount / totalJobs) * 100).round()
        : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;

        final card1 = _KpiCard(
          icon: Icons.work_outline,
          iconColor: const Color(0xFF2563EB),
          iconBgColor: const Color(0xFFEFF6FF),
          title: 'Total Lowongan Aktif',
          value: '$totalJobs',
          subtitle: 'Tersedia dari database lokal & mitra global',
          badgeText: 'Live Data',
          badgeColor: const Color(0xFF2563EB),
        );

        final card2 = _KpiCard(
          icon: Icons.payments_outlined,
          iconColor: const Color(0xFF059669),
          iconBgColor: const Color(0xFFECFDF5),
          title: 'Rasio Kompensasi',
          value: '$paidPercentage% Paid',
          subtitle: '$paidCount berbayar • $unpaidCount belum spesifik',
          badgeText: '$paidCount Lowongan',
          badgeColor: const Color(0xFF059669),
        );

        final card3 = _KpiCard(
          icon: Icons.public_outlined,
          iconColor: const Color(0xFF0891B2),
          iconBgColor: const Color(0xFFECFEFF),
          title: 'Distribusi Kerja',
          value: '$remotePercentage% Remote',
          subtitle: '$remoteCount remote • $onsiteHybridCount onsite/hybrid',
          badgeText: '$remoteCount Remote',
          badgeColor: const Color(0xFF0891B2),
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: card1),
              const SizedBox(width: 16),
              Expanded(child: card2),
              const SizedBox(width: 16),
              Expanded(child: card3),
            ],
          );
        }

        return Column(
          children: [
            card1,
            const SizedBox(height: 12),
            card2,
            const SizedBox(height: 12),
            card3,
          ],
        );
      },
    );
  }

  Widget _buildTopSkillsSection() {
    final topSkillsRaw = _marketTrends?['top_skills'] as List? ?? [];
    final totalJobs = (_marketTrends?['total_jobs'] as num?)?.toInt() ?? 1;

    final topSkills = topSkillsRaw.whereType<Map<String, dynamic>>().toList();

    int maxCount = 1;
    for (final s in topSkills) {
      final count = (s['count'] as num?)?.toInt() ?? 0;
      if (count > maxCount) maxCount = count;
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentDark.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: AppColors.accentDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '8 Top Demanded Skills',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Keahlian yang paling sering disyaratkan dalam lowongan saat ini',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (topSkills.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Data skill belum tersedia')),
            )
          else
            Column(
              children: [
                for (int i = 0; i < topSkills.length; i++) ...[
                  _buildSkillBarItem(
                    rank: i + 1,
                    skillName: (topSkills[i]['skill'] ?? '').toString(),
                    count: (topSkills[i]['count'] as num?)?.toInt() ?? 0,
                    maxCount: maxCount,
                    totalJobs: totalJobs,
                  ),
                  if (i < topSkills.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSkillBarItem({
    required int rank,
    required String skillName,
    required int count,
    required int maxCount,
    required int totalJobs,
  }) {
    final double ratio = maxCount > 0
        ? (count / maxCount).clamp(0.0, 1.0)
        : 0.0;
    final double marketShare = totalJobs > 0
        ? ((count / totalJobs) * 100)
        : 0.0;

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: rank <= 3 ? AppColors.primary : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: rank <= 3 ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 110,
          child: Text(
            skillName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    height: 18,
                    width: constraints.maxWidth * ratio,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: rank == 1
                            ? [const Color(0xFF1E3A8A), const Color(0xFF0EA5E9)]
                            : [
                                const Color(0xFF0EA5E9),
                                const Color(0xFF38BDF8),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 90,
          child: Text(
            '$count lowongan (${marketShare.toStringAsFixed(0)}%)',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScarcityIndexSection() {
    final filtered = _skillScarcity.where((item) {
      if (_selectedCategoryFilter == 'Semua') return true;
      if (_selectedCategoryFilter == 'Dikuasai Saya') {
        return item['user_has_skill'] == true;
      }
      return item['category'] == _selectedCategoryFilter;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.balance_outlined,
                  color: Color(0xFF059669),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Skill Supply vs. Demand Scarcity Index',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Perbandingan permintaan industri (Demand) vs kandidat (Supply). High Opportunity = Peluang diterima tertinggi.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filter buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final cat in [
                  'Semua',
                  'High Opportunity',
                  'Competitive',
                  'Niche',
                  'Dikuasai Saya',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat),
                      selected: _selectedCategoryFilter == cat,
                      onSelected: (_) =>
                          setState(() => _selectedCategoryFilter = cat),
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedCategoryFilter == cat
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: _selectedCategoryFilter == cat
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Tidak ada skill yang cocok dengan filter "$_selectedCategoryFilter".',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;

                return Column(
                  children: [
                    for (int i = 0; i < filtered.length; i++) ...[
                      _ScarcityCard(item: filtered[i], isWide: isWide),
                      if (i < filtered.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String value;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;

  const _KpiCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScarcityCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isWide;

  const _ScarcityCard({required this.item, required this.isWide});

  @override
  State<_ScarcityCard> createState() => _ScarcityCardState();
}

class _ScarcityCardState extends State<_ScarcityCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final skill = widget.item['skill']?.toString() ?? '-';
    final category = widget.item['category']?.toString() ?? 'Niche';
    final scarcityIndex =
        (widget.item['scarcity_index'] as num?)?.toDouble() ?? 0.0;
    final demandRate = (widget.item['demand_rate'] as num?)?.toDouble() ?? 0.0;
    final supplyRate = (widget.item['supply_rate'] as num?)?.toDouble() ?? 0.0;
    final userHasSkill = widget.item['user_has_skill'] == true;

    Color badgeColor;
    Color badgeBg;
    IconData badgeIcon;

    if (category == 'High Opportunity') {
      badgeColor = const Color(0xFF059669); // Emerald
      badgeBg = const Color(0xFFECFDF5);
      badgeIcon = Icons.rocket_launch_outlined;
    } else if (category == 'Competitive') {
      badgeColor = const Color(0xFFD97706); // Amber
      badgeBg = const Color(0xFFFFFBEB);
      badgeIcon = Icons.people_outline;
    } else {
      badgeColor = const Color(0xFF7C3AED); // Purple
      badgeBg = const Color(0xFFF5F3FF);
      badgeIcon = Icons.auto_awesome_outlined;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: userHasSkill ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: userHasSkill
                ? const Color(0xFF86EFAC)
                : (_isHovered ? AppColors.accentDark : AppColors.border),
            width: userHasSkill || _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? Colors.black.withValues(alpha: 0.06)
                  : Colors.transparent,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        skill,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, size: 12, color: badgeColor),
                            const SizedBox(width: 4),
                            Text(
                              category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: badgeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (userHasSkill) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF0284C7)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 12,
                                color: Color(0xFF0284C7),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Dikuasai Saya',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Scarcity: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        scarcityIndex.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Comparison Bars: Demand vs Supply
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Demand (Kebutuhan Lowongan)',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${demandRate.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (demandRate / 100).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF2563EB),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Supply (Ketersediaan Kandidat)',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${supplyRate.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (supplyRate / 100).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF059669),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _RecommendationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = (data['job_title'] ?? '-') as String;
    final company = (data['company_name'] ?? '-') as String;
    final location = (data['location'] ?? 'Remote') as String;
    final salary = data['salary_range'] as String?;
    final percentage = (data['match_percentage'] as num?)?.toInt() ?? 70;
    final reason = (data['reason'] ?? '') as String;
    final url = (data['job_url'] as String?);

    final matchedSkillsRaw = (data['matched_skills'] as List?) ?? [];
    final matchedSkills = matchedSkillsRaw.map((e) => e.toString()).toList();

    final missingSkillsRaw = (data['missing_skills'] as List?) ?? [];
    final missingSkills = missingSkillsRaw.map((e) => e.toString()).toList();

    // Warna indikator persentase
    final Color badgeColor;
    final Color badgeBg;
    final Color badgeBorder;
    if (percentage >= 85) {
      badgeColor = const Color(0xFF047857);
      badgeBg = const Color(0xFFECFDF5);
      badgeBorder = const Color(0xFFA7F3D0);
    } else if (percentage >= 75) {
      badgeColor = const Color(0xFF1D4ED8);
      badgeBg = const Color(0xFFEFF6FF);
      badgeBorder = const Color(0xFFBFDBFE);
    } else {
      badgeColor = const Color(0xFFB45309);
      badgeBg = const Color(0xFFFFFBEB);
      badgeBorder = const Color(0xFFFDE68A);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Judul Posisi & Badge Persentase Peluang Diterima
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 14, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      '$percentage% Peluang Diterima',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Meta: Perusahaan, Lokasi, dan Gaji
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.business_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    company,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ],
                ),
              ),
              if (salary != null && salary.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.payments_outlined,
                        size: 12,
                        color: Color(0xFF059669),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        salary,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Chip Keahlian yang Cocok (Matched Skills)
          if (matchedSkills.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Skill Cocok:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
                for (final s in matchedSkills)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check,
                          size: 11,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          s,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Chip Keahlian Tambahan yang Disarankan (Missing Skills)
          if (missingSkills.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Saran Tambahan:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309),
                  ),
                ),
                for (final s in missingSkills)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_circle_outline,
                          size: 11,
                          color: Color(0xFFB45309),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          s,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Kotak Alasan Rekomendasi (Personalized AI Reason)
          if (reason.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.psychology_outlined,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (url != null && url.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () async {
                  try {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  } catch (_) {}
                },
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text(
                  'Lihat Detail Lowongan / Lamar',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
