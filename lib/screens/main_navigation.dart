import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/tracker_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
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
    _ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.work_outline), activeIcon: Icon(Icons.work), label: 'Lowongan'),
          BottomNavigationBarItem(icon: Icon(Icons.view_kanban_outlined), activeIcon: Icon(Icons.view_kanban), label: 'Tracker'),
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
      appBar: AppBar(title: const Text('Profil')),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 32, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(child: Text(user.name, style: Theme.of(context).textTheme.headlineSmall)),
                Center(child: Text(user.email, style: Theme.of(context).textTheme.bodySmall)),
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.school_outlined, color: AppColors.accentDark),
                    title: const Text('Jurusan'),
                    subtitle: Text(user.major ?? '-'),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Keahlian', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        user.skills.isEmpty
                            ? const Text('Belum ada keahlian')
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: user.skills.map((s) => Chip(label: Text(s))).toList(),
                              ),
                      ],
                    ),
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
    );
  }
}
