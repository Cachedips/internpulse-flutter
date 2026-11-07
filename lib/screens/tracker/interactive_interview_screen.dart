import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';

import '../../models/tracker_model.dart';
import '../../providers/tracker_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

enum _Role { ai, user, feedback }

class _Msg {
  final _Role role;
  final String text;
  final int? score;
  const _Msg(this.role, this.text, {this.score});
}

/// Simulasi wawancara:
/// POST /trackers/{id}/interview/question  -> {question}
/// POST /trackers/{id}/interview/answer    -> {score, feedback}
class InteractiveInterviewScreen extends StatefulWidget {
  final TrackerModel tracker;
  const InteractiveInterviewScreen({super.key, required this.tracker});

  @override
  State<InteractiveInterviewScreen> createState() =>
      _InteractiveInterviewScreenState();
}

class _InteractiveInterviewScreenState
    extends State<InteractiveInterviewScreen> {
  final _answerCtrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [];

  String _currentQuestion = '';
  bool _busy = false;
  bool _awaitingNext = false;

  @override
  void initState() {
    super.initState();
    _loadQuestion();
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadQuestion() async {
    setState(() {
      _busy = true;
      _awaitingNext = false;
    });
    try {
      final q = await context.read<TrackerProvider>().nextInterviewQuestion(
        widget.tracker,
      );
      _currentQuestion = q;
      _messages.add(_Msg(_Role.ai, q));
    } on ApiException catch (e) {
      _messages.add(
        _Msg(_Role.feedback, 'Gagal memuat pertanyaan: ${e.message}'),
      );
    }
    if (mounted) setState(() => _busy = false);
    _scrollToEnd();
  }

  Future<void> _submit() async {
    final answer = _answerCtrl.text.trim();
    if (answer.isEmpty || _busy || _currentQuestion.isEmpty) return;

    setState(() {
      _messages.add(_Msg(_Role.user, answer));
      _busy = true;
    });
    _answerCtrl.clear();
    _scrollToEnd();

    try {
      final res = await context.read<TrackerProvider>().submitInterviewAnswer(
        widget.tracker,
        _currentQuestion,
        answer,
      );
      final d = (res['data'] ?? res) as Map<String, dynamic>;
      _messages.add(
        _Msg(
          _Role.feedback,
          '${d['feedback'] ?? ''}',
          score: ((d['score'] ?? 0) as num).toInt().clamp(0, 100),
        ),
      );
      _awaitingNext = true;
    } on ApiException catch (e) {
      _messages.add(
        _Msg(_Role.feedback, 'Gagal menilai jawaban: ${e.message}'),
      );
    }
    if (mounted) setState(() => _busy = false);
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Interview: ${widget.tracker.companyName}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_busy ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                return _Bubble(msg: _messages[i]);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: _awaitingNext
                  ? ElevatedButton.icon(
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Pertanyaan Berikutnya'),
                      onPressed: _busy ? null : _loadQuestion,
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _answerCtrl,
                            minLines: 1,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              hintText: 'Ketik jawaban Anda...',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          onPressed: _busy ? null : _submit,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _Msg msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == _Role.user;
    final isFeedback = msg.role == _Role.feedback;

    final bg = isUser
        ? AppColors.primary
        : (isFeedback
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.surface);
    final fg = isUser ? Colors.white : AppColors.textPrimary;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: isUser ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.role == _Role.ai)
              Text(
                'Pewawancara AI',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.accentDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (msg.score != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircularPercentIndicator(
                      radius: 30,
                      lineWidth: 6,
                      percent: msg.score! / 100,
                      circularStrokeCap: CircularStrokeCap.round,
                      progressColor: msg.score! >= 70
                          ? AppColors.success
                          : (msg.score! >= 40
                                ? AppColors.warning
                                : AppColors.danger),
                      backgroundColor: AppColors.border,
                      center: Text(
                        '${msg.score}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Skor jawaban',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            Text(msg.text, style: TextStyle(color: fg, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
