import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Bottom sheet AI Follow-up Generator (email / pesan LinkedIn).
class FollowUpEmailModal extends StatefulWidget {
  final Future<String> Function(String type) generator;
  const FollowUpEmailModal({super.key, required this.generator});

  static Future<void> show(BuildContext context, Future<String> Function(String) generator) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: FollowUpEmailModal(generator: generator),
      ),
    );
  }

  @override
  State<FollowUpEmailModal> createState() => _FollowUpEmailModalState();
}

class _FollowUpEmailModalState extends State<FollowUpEmailModal> {
  String _type = 'email';
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.generator(_type);
  }

  void _regenerate(String type) {
    setState(() {
      _type = type;
      _future = widget.generator(type);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Follow-up Generator', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'email', label: Text('Email'), icon: Icon(Icons.email_outlined)),
              ButtonSegment(value: 'linkedin', label: Text('LinkedIn'), icon: Icon(Icons.chat_outlined)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => _regenerate(s.first),
          ),
          const SizedBox(height: 16),
          FutureBuilder<String>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Text('Gagal membuat draf: ${snap.error}');
              }
              final text = snap.data ?? '';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SingleChildScrollView(child: SelectableText(text)),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Salin Teks'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Draf disalin')));
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _regenerate(_type),
                    child: const Text('Buat ulang'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
