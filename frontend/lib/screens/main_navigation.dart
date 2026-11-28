import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../providers/tracker_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'analytics/analytics_screen.dart';
import 'home/job_feed_screen.dart';
import 'tracker/kanban_tracker_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 0;

  final _pages = const [
    JobFeedScreen(),
    KanbanTrackerScreen(),
    AnalyticsScreen(),
    _ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: 'Lowongan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_kanban_outlined),
            activeIcon: Icon(Icons.view_kanban),
            label: 'Tracker',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights_outlined),
            activeIcon: Icon(Icons.insights),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

/// Tab profil: info user + Universal AI CV Analyzer + Analisis AI CV + Jurusan + Keahlian + logout.
class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  Map<String, dynamic>? _analysis;

  @override
  void initState() {
    super.initState();
    _loadSavedAnalysis();
  }

  Future<void> _loadSavedAnalysis() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('latest_cv_analysis');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> && mounted) {
          setState(() {
            _analysis = decoded;
          });
        }
      }
    } catch (_) {}
  }

  void _onAnalysisExtracted(Map<String, dynamic> analysis) {
    setState(() {
      _analysis = analysis;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profil')),
      body: user == null
          ? const SizedBox.shrink()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  children: [
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
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 28,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.email,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _AiCvSkillExtractorCard(
                      onAnalysisExtracted: _onAnalysisExtracted,
                    ),
                    if (_analysis != null) ...[
                      const SizedBox(height: 16),
                      _AiCvAnalysisCard(
                        analysis: _analysis!,
                        onDismiss: () async {
                          setState(() => _analysis = null);
                          try {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('latest_cv_analysis');
                          } catch (_) {}
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
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
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentDark.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.school_outlined,
                            color: AppColors.accentDark,
                          ),
                        ),
                        title: const Text(
                          'Jurusan / Program Studi',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        subtitle: Text(
                          user.major ?? '-',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
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
                              Text(
                                'Keahlian',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              if (user.skills.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentDark.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${user.skills.length} skill',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accentDark,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          user.skills.isEmpty
                              ? const Text(
                                  'Belum ada keahlian. Gunakan AI CV Analyzer di atas.',
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: user.skills
                                      .map(
                                        (s) => Chip(
                                          avatar: const Icon(
                                            Icons.check_circle_outline,
                                            size: 14,
                                            color: AppColors.accentDark,
                                          ),
                                          label: Text(s),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Keluar'),
                      onPressed: () async {
                        context.read<TrackerProvider>().reset();
                        await context.read<AuthService>().logout();
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Kartu Universal AI CV Analyzer: upload file PDF/TXT atau tempel teks CV.
class _AiCvSkillExtractorCard extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>>? onAnalysisExtracted;

  const _AiCvSkillExtractorCard({this.onAnalysisExtracted});

  @override
  State<_AiCvSkillExtractorCard> createState() =>
      _AiCvSkillExtractorCardState();
}

class _AiCvSkillExtractorCardState extends State<_AiCvSkillExtractorCard> {
  final _cvTextCtrl = TextEditingController();
  Uint8List? _fileBytes;
  String? _fileName;
  bool _loading = false;

  @override
  void dispose() {
    _cvTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );
      if (files.isNotEmpty) {
        final f = files.first;
        final bytes = await f.readAsBytes();
        if (bytes.isNotEmpty) {
          setState(() {
            _fileBytes = bytes;
            _fileName = f.name;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal memilih file: $e')));
    }
  }

  Future<void> _submit() async {
    final text = _cvTextCtrl.text.trim();
    if (_fileBytes == null && text.length < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Harap unggah file CV (PDF/TXT) atau tempel teks CV minimal 50 karakter.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final res = await ApiService().extractCv(
        cvText: text.isNotEmpty ? text : null,
        fileBytes: _fileBytes,
        fileName: _fileName,
      );

      if (!mounted) return;

      if (res['user'] is Map<String, dynamic>) {
        final updated = UserModel.fromJson(res['user'] as Map<String, dynamic>);
        if (mounted) {
          context.read<AuthService>().updateUser(updated);
        }
      }

      // Pastikan state profil & UserProvider di-refresh agar halaman Analytics langsung sinkron
      if (mounted) {
        await context.read<AuthService>().refreshProfile();
      }

      if (!mounted) return;

      final skills =
          (res['extracted_skills'] as List?) ?? (res['skills'] as List?) ?? [];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message'] != null
                ? '${res['message']} (${skills.length} keahlian terdaftar)'
                : 'CV berhasil dianalisis! (${skills.length} keahlian)',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Render dan simpan kartu Analisis AI CV
      if (res['analysis'] is Map<String, dynamic>) {
        final analysis = res['analysis'] as Map<String, dynamic>;
        widget.onAnalysisExtracted?.call(analysis);
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('latest_cv_analysis', jsonEncode(analysis));
        } catch (_) {}
      }

      _cvTextCtrl.clear();
      setState(() {
        _fileBytes = null;
        _fileName = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menganalisis CV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      color: AppColors.accent.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    Icons.auto_awesome,
                    color: AppColors.accentDark,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Universal AI CV Analyzer',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Membaca & menganalisis CV lintas jurusan secara otomatis',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // File upload button or selected file indicator
            if (_fileBytes == null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Pilih File CV (PDF / TXT)'),
                onPressed: _loading ? null : _pickFile,
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.accentDark.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf,
                      color: AppColors.accentDark,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _fileName ?? 'File CV terpilih',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${((_fileBytes?.lengthInBytes ?? 0) / 1024).toStringAsFixed(1)} KB',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                              _fileBytes = null;
                              _fileName = null;
                            }),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'ATAU TEMPEL TEKS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cvTextCtrl,
              minLines: 3,
              maxLines: 6,
              enabled: !_loading,
              decoration: InputDecoration(
                hintText: 'Tempel teks isi CV atau ringkasan keahlian Anda di sini (minimal 50 karakter)...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_loading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Universal AI sedang membaca & menganalisis seluruh isi CV...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppColors.accentDark,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Analisis CV Sekarang'),
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu Hasil Analisis AI CV Universal (Summary, Rekomendasi Posisi, Kekuatan, & Saran Peningkatan)
class _AiCvAnalysisCard extends StatelessWidget {
  final Map<String, dynamic> analysis;
  final VoidCallback? onDismiss;

  const _AiCvAnalysisCard({required this.analysis, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final summary = (analysis['summary'] as String?)?.trim() ?? '';
    final roles =
        (analysis['recommended_roles'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];
    final strengths =
        (analysis['strengths'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];
    final improvements =
        (analysis['improvements'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentDark.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accentDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.psychology_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Analisis AI CV',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Universal AI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ringkasan profil, kekuatan, & rekomendasi posisi',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: onDismiss,
                    tooltip: 'Tutup Kartu Analisis',
                  ),
              ],
            ),

            // 1. Ringkasan Profesional (Summary)
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.format_quote_rounded,
                      color: AppColors.accentDark,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        summary,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 2. Rekomendasi Posisi Magang & Kerja (Chip/Tag)
            if (roles.isNotEmpty) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(
                    Icons.work_outline_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Rekomendasi Posisi Magang & Kerja',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: roles.map((role) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          size: 15,
                          color: AppColors.accentDark,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          role,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            // 3. Kekuatan Utama Kandidat (Strengths)
            if (strengths.isNotEmpty) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Kekuatan Utama Berdasarkan CV',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...strengths.map(
                (str) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2, right: 8),
                        child: Icon(
                          Icons.check,
                          size: 15,
                          color: AppColors.success,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          str,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // 4. Saran Peningkatan Kualitas CV (Improvements)
            if (improvements.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Saran Peningkatan Kualitas CV',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...improvements.map(
                (imp) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2, right: 8),
                        child: Icon(
                          Icons.trending_up_rounded,
                          size: 15,
                          color: AppColors.warning,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          imp,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
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
