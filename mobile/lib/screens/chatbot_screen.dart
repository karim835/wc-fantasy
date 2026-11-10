import 'package:flutter/material.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import '../services/api_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<_Message> _messages = [];
  final List<Map<String, String>> _history = [];
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isTyping = false;

  // Quick suggestion prompts
  final _suggestions = [
    'Who should I pick this week?',
    'Best budget defenders?',
    'Transfer suggestions for my team',
    'Risk score for my captain',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_Message(
      text: "Hi! I'm your WC Fantasy AI assistant. Ask me about transfers, player picks, or risk analysis!",
      isBot: true,
    ));
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _textCtrl.clear();

    setState(() {
      _messages.add(_Message(text: text, isBot: false));
      _isTyping = true;
    });
    _scrollToBottom();

    // Try real Gemini backend first, fall back to local responses
    final response = await _getAIResponse(text);

    setState(() {
      _isTyping = false;
      _messages.add(_Message(text: response, isBot: true));
    });
    // Add to history for context
    _history.add({'role': 'user', 'content': text});
    _history.add({'role': 'assistant', 'content': response});
    // Keep history to last 10 exchanges to avoid large payloads
    if (_history.length > 20) _history.removeRange(0, 2);
    _scrollToBottom();
  }

  Future<String> _getAIResponse(String query) async {
    // Try the real Gemini-powered backend chatbot first
    try {
      return await apiService.sendChatbotMessage(query, List.from(_history));
    } catch (_) {
      // Backend unavailable or GEMINI_API_KEY not set — fall back to local responses
    }

    // Local fallback responses
    final q = query.toLowerCase();

    if (q.contains('transfer') || q.contains('suggestion')) {
      return 'I suggest looking for high-form players under \$8M in your weakest position. '
          'Check fixture difficulty and injury status before transferring.';
    }

    if (q.contains('risk')) {
      return 'For risk analysis, check injury status, recent form, and fixture difficulty. '
          'Avoid players with injury doubts or suspensions as captains.';
    }

    if (q.contains('captain') || q.contains('pick')) {
      return 'For captaincy, pick the player with the highest form playing at home against a weak defense. '
          'Forwards from top-6 clubs are often safe bets.';
    }

    if (q.contains('budget') || q.contains('cheap')) {
      return 'Great budget picks (under \$6M): look for defenders from strong defensive teams — '
          'they earn clean sheet bonuses plus assist points. Midfielders with good set-piece duties are also great value.';
    }

    if (q.contains('formation')) {
      return 'Popular formations:\n• 4-3-3: Balanced, great for midfield depth\n'
          '• 3-5-2: Max midfield coverage\n'
          '• 4-4-2: Classic, strong in attack\n\n'
          'Choose based on which positions have the best fixtures this week.';
    }

    return 'Great question! For the best results, check player form, fixtures, and injury status. '
        'Want me to analyze a specific player or position?';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandAppBar(
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.gold,
              child: Icon(Icons.smart_toy, size: 18, color: Colors.black),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Assistant', style: TextStyle(fontSize: 16)),
                Text('WC Fantasy Expert', style: TextStyle(fontSize: 11, color: Colors.white60)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Suggestions
          if (_messages.length == 1) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions.map((s) => ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  onPressed: () => _send(s),
                  backgroundColor: AppColors.surface,
                )).toList(),
              ),
            ),
          ],

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (_, i) {
                if (_isTyping && i == _messages.length) {
                  return _TypingIndicator();
                }
                return _MessageBubble(message: _messages[i]);
              },
            ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ask me anything...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _send(_textCtrl.text),
                  icon: const Icon(Icons.send_rounded, color: AppColors.gold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isBot;
  _Message({required this.text, required this.isBot});
}

class _MessageBubble extends StatelessWidget {
  final _Message message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: message.isBot ? AppColors.surface : AppColors.gold,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: message.isBot ? Radius.zero : null,
            bottomRight: message.isBot ? null : Radius.zero,
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: message.isBot ? Colors.white : Colors.black, fontSize: 14),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: Radius.zero),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(delay: Duration.zero),
            SizedBox(width: 4),
            _Dot(delay: Duration(milliseconds: 200)),
            SizedBox(width: 4),
            _Dot(delay: Duration(milliseconds: 400)),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Duration delay;
  const _Dot({required this.delay});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 8, height: 8, child: DecoratedBox(decoration: BoxDecoration(color: Colors.white54, shape: BoxShape.circle)));
}
