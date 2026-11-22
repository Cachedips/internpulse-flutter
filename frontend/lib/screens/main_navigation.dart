import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.work_outline), activeIcon: Icon(Icons.work), label: 'Lowongan'),
          BottomNavigationBarItem(icon: Icon(Icons.view_kanban_outlined), activeIcon: Icon(Icons.view_kanban), label: 'Tracker'),
          BottomNavigationBarItem(icon: Icon(Icons.insights_outlined), activeIcon: Icon(Icons.insights), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

/// Tab profil sederhana: info user + keahlian + logout.
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(user.email, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _AiCvSkillExtractorCard(),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentDark.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.school_outlined, color: AppColors.accentDark),
                    ),
                    title: const Text('Jurusan / Program Studi', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    subtitle: Text(
                      user.major ?? '-',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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
                            Text('Keahlian', style: Theme.of(context).textTheme.titleMedium),
                            const Spacer(),
                            if (user.skills.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentDark.withValues(alpha: 0.12),
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
                            ? const Text('Belum ada keahlian. Gunakan AI CV Extractor di atas.')
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: user.skills
                                    .map(
                                      (s) => Chip(
                                        avatar: const Icon(Icons.check_circle_outline, size: 14, color: AppColors.accentDark),
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

/// Kartu AI CV Skill Extractor: upload file PDF/TXT atau tempel teks CV.
class _AiCvSkillExtractorCard extends StatefulWidget {
  const _AiCvSkillExtractorCard();

  @override
  State<_AiCvSkillExtractorCard> createState() => _AiCvSkillExtractorCardState();
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
        setState(() {
          _fileBytes = bytes;
          _fileName = f.name;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih file: $e')),
      );
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
      } else {
        if (mounted) {
          await context.read<AuthService>().refreshProfile();
        }
      }

      if (!mounted) return;

      final skills = (res['extracted_skills'] as List?) ?? [];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message'] != null
                ? '${res['message']} (${skills.length} keahlian terdaftar)'
                : 'CV berhasil diekstrak! (${skills.length} keahlian)',
          ),
          backgroundColor: Colors.green,
        ),
      );

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
        SnackBar(content: Text('Gagal mengekstrak CV: $e'), backgroundColor: Colors.red),
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
                  child: const Icon(Icons.auto_awesome, color: AppColors.accentDark, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI CV Skill Extractor',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Ekstrak keahlian & jurusan otomatis dari CV',
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
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Pilih File CV (PDF / TXT)'),
                onPressed: _loading ? null : _pickFile,
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accentDark.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: AppColors.accentDark, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _fileName ?? 'File CV terpilih',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
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
                hintText: 'Tempel ringkasan isi CV atau daftar keahlian Anda di sini (minimal 50 karakter)...',
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
                  'Gemini AI sedang membaca & mengekstrak CV...',
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
              label: const Text('Ekstrak Keahlian Sekarang'),
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
