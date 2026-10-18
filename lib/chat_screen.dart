import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_state.dart';
import 'chat_database.dart';

/// Endpoint of the Cloudflare Worker proxy.
/// The NVIDIA API key stays server-side inside the worker.
const String kProxyUrl = 'https://mindspark-ai-proxy.adamed135.workers.dev';

const String kDefaultModel = 'meta/llama-3.2-11b-vision-instruct';

/// Substrings that indicate an AI reply is about one of the allowed school
/// subjects (Math, Science, Physics, Geography, History) in the app's UI
/// languages plus common international spellings.
const List<String> allowedSubjectHints = [
  // Math
  'math', 'calcu', 'algeb', 'geometr', 'number', 'رياضيات', 'حساب', 'الهندسة',
  'matem', '数学',
  // Science
  'science', 'sciences', 'biolog', 'chemi', 'astronom', 'planet', 'space',
  'علوم', 'كيمياء', 'أحياء', 'فلك', 'scien', '科学', 'ciencia',
  // Physics
  'physic', 'physique', 'físic', 'energy', 'force', 'طاقة', 'فيزياء', '物理',
  // Geography
  'geograph', 'géograph', 'geo ', 'الجغرافيا', 'خريطة', 'world', 'capital',
  'geograf',
  // History
  'histor', 'histoir', 'تاريخ', 'تاريخية', 'century', 'siècle', 'ancient',
];

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final bool isError;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = false;
  int? _currentSessionId;
  List<ChatSession> _sessions = [];

  AppState get appState => widget.appState;

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(isUser: false, text: appState.t('chatGreeting')));
    _loadSessions();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await ChatDatabase.listSessions();
      if (mounted) setState(() => _sessions = sessions);
    } catch (_) {
      // Database unavailable — sidebar just stays empty.
    }
  }

  void _startNewChat() {
    setState(() {
      _currentSessionId = null;
      _messages
        ..clear()
        ..add(ChatMessage(isUser: false, text: appState.t('chatGreeting')));
    });
    Navigator.of(context).pop(); // close sidebar
  }

  Future<void> _openSession(ChatSession session) async {
    Navigator.of(context).pop(); // close sidebar
    try {
      final stored = await ChatDatabase.listMessages(session.id);
      if (!mounted) return;
      setState(() {
        _currentSessionId = session.id;
        _messages
          ..clear()
          ..add(ChatMessage(isUser: false, text: appState.t('chatGreeting')));
        for (final m in stored) {
          _messages.add(ChatMessage(text: m.content, isUser: m.role == 'user'));
        }
      });
      _scrollToBottom(instant: true);
    } catch (_) {
      // Ignore load failures.
    }
  }

  Future<void> _deleteSession(ChatSession session) async {
    try {
      await ChatDatabase.deleteSession(session.id);
    } catch (_) {}
    if (_currentSessionId == session.id) {
      setState(() {
        _currentSessionId = null;
        _messages
          ..clear()
          ..add(ChatMessage(isUser: false, text: appState.t('chatGreeting')));
      });
    }
    _loadSessions();
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _inputController.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    // Lazily create the DB session with the first user message as title.
    if (_currentSessionId == null) {
      try {
        final id = await ChatDatabase.createSession(
          text.length > 40 ? '${text.substring(0, 40)}…' : text,
        );
        _currentSessionId = id;
      } catch (_) {}
    }
    final sessionId = _currentSessionId;
    if (sessionId != null) {
      try {
        await ChatDatabase.addMessage(sessionId, role: 'user', content: text);
      } catch (_) {}
    }

    try {
      final aiReply = await _fetchAiReply();
      // Client-side guard: if the reply has no hint of an allowed school
      // subject, the model slipped off-topic — show the localized redirect.
      final onTopic = allowedSubjectHints.any(
        (hint) => aiReply.toLowerCase().contains(hint),
      );
      final reply = onTopic ? aiReply : appState.t('offTopicRedirect');
      setState(() {
        _messages.add(ChatMessage(text: reply, isUser: false));
        _isLoading = false;
      });
      if (sessionId != null) {
        try {
          await ChatDatabase.addMessage(sessionId, role: 'assistant', content: reply);
        } catch (_) {}
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: '${appState.t('errorPrefix')}: $e',
          isUser: false,
          isError: true,
        ));
        _isLoading = false;
      });
    }
    _scrollToBottom();
    _loadSessions();
  }

  Future<String> _fetchAiReply() async {
    final history = <Map<String, String>>[
      {
        'role': 'system',
        'content':
            'You are MindSpark AI, a friendly tutor ONLY for children aged 10 to 15. '
                'Use simple, positive vocabulary and short sentences a 10–15 year old '
                'understands, and encourage curiosity. Never discuss adult, violent or '
                'frightening topics.\n'
                'You ONLY teach these school subjects: Geography, History, Science, '
                'Math and Physics (the same classes used in the quiz section).\n'
                'If the child asks about ANYTHING outside these subjects (coding, '
                'sports, movies, games, celebrities, other school subjects, personal '
                'matters), do NOT answer it. Instead reply ONLY with a short, friendly '
                'reminder that you can just help with Geography, History, Science, '
                'Math and Physics, plus a warm invitation to pick one of those.\n'
                'For on-topic questions: keep examples worldwide — never assume the '
                'child lives in one specific country (no US, Canada, UK or other '
                'country-specific curriculum).\n'
                "Reply in the language of the child's last message.",
      },
      for (final m in _messages)
        if (!m.isError) {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
    ];

    final response = await http.post(
      Uri.parse(kProxyUrl),
      body: jsonEncode({'model': kDefaultModel, 'messages': history}),
      headers: const {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Server error ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    final content = choices?[0]?['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw Exception('Empty response from AI');
    }
    return content.trim();
  }

  void _scrollToBottom({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (instant) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildRecentChatsDrawer(context),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          tooltip: appState.t('recentChats'),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 22),
            const SizedBox(width: 8),
            Flexible(child: Text(appState.t('chatTitle'), overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: appState.t('newChat'),
            icon: const Icon(Icons.add_comment_rounded),
            onPressed: _startNewChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildTypingIndicator(colorScheme);
                }
                final message = _messages[index];
                return _buildMessageBubble(message, colorScheme);
              },
            ),
          ),
          _buildInputBar(colorScheme),
        ],
      ),
    );
  }

  /// Sidebar (drawer) listing recent chats from SQLite.
  Widget _buildRecentChatsDrawer(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appState.t('recentChats'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilledButton.tonalIcon(
                onPressed: _startNewChat,
                icon: const Icon(Icons.add_rounded),
                label: Text(appState.t('newChat')),
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: _sessions.isEmpty
                  ? Center(
                      child: Text(
                        appState.t('noRecentChats'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        final selected = session.id == _currentSessionId;
                        return ListTile(
                          leading: Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 20,
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          selected: selected,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20),
                            tooltip: 'Delete',
                            onPressed: () => _deleteSession(session),
                          ),
                          onTap: () => _openSession(session),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, ColorScheme colorScheme) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: message.isError
              ? colorScheme.errorContainer
              : message.isUser
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: message.isUser
                ? const Radius.circular(18)
                : const Radius.circular(4),
            bottomRight: message.isUser
                ? const Radius.circular(4)
                : const Radius.circular(18),
          ),
        ),
        child: SelectableText(
          message.text,
          style: TextStyle(
            color: message.isError
                ? colorScheme.onErrorContainer
                : message.isUser
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(ColorScheme colorScheme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Thinking…'),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(ColorScheme colorScheme) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: appState.t('askAnything'),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isLoading ? null : _sendMessage,
              icon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
