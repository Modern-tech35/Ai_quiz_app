import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// A saved chat conversation (one row in the sessions table).
class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  static ChatSession fromMap(Map<String, dynamic> map) => ChatSession(
        id: map['id'] as int,
        title: map['title'] as String,
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      );

  Map<String, dynamic> toJson() => toMap();

  static ChatSession fromJson(Map<String, dynamic> json) => fromMap(json);
}

/// A single stored chat message belonging to a session.
class StoredMessage {
  StoredMessage({
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final int sessionId;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'session_id': sessionId,
        'role': role,
        'content': content,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static StoredMessage fromMap(Map<String, dynamic> map) => StoredMessage(
        sessionId: map['session_id'] as int,
        role: map['role'] as String,
        content: map['content'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}

/// Local persistence for chat sessions and messages.
///
/// - Android: real SQLite via sqflite.
/// - Web: a JSON store persisted in browser local storage via
///   shared_preferences (SQLite native/wasm is not used on the web build).
class ChatDatabase {
  ChatDatabase._();

  static Database? _db;
  static List<ChatSession>? _webSessions;
  static final Map<int, List<StoredMessage>> _webMessages = {};
  static int _webNextId = 1;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  static Future<int> createSession(String title) async {
    if (kIsWeb) return _webCreateSession(title);
    final db = await _open();
    return db.insert('sessions', {
      'title': title,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<void> renameSession(int id, String title) async {
    if (kIsWeb) {
      await _webMutateSessions((sessions) {
        for (final i in sessions) {
          if (i.id == id) {
            sessions.remove(i);
            sessions.insert(
              0,
              ChatSession(id: id, title: title, updatedAt: DateTime.now()),
            );
            break;
          }
        }
      });
      return;
    }
    final db = await _open();
    await db.update(
      'sessions',
      {'title': title, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> touchSession(int id) async {
    if (kIsWeb) {
      await _webMutateSessions((sessions) {
        final index = sessions.indexWhere((s) => s.id == id);
        if (index != -1) {
          final s = sessions.removeAt(index);
          sessions.insert(
              0, ChatSession(id: s.id, title: s.title, updatedAt: DateTime.now()));
        }
      });
      return;
    }
    final db = await _open();
    await db.update(
      'sessions',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteSession(int id) async {
    if (kIsWeb) {
      _webMessages.remove(id);
      await _webMutateSessions((sessions) => sessions.removeWhere((s) => s.id == id));
      await _webSaveMessages();
      return;
    }
    final db = await _open();
    await db.delete('messages', where: 'session_id = ?', whereArgs: [id]);
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  /// Sessions ordered most-recent first.
  static Future<List<ChatSession>> listSessions() async {
    if (kIsWeb) {
      await _webLoad();
      return List.of(_webSessions!);
    }
    final db = await _open();
    final rows = await db.query('sessions', orderBy: 'updated_at DESC', limit: 50);
    return rows.map(ChatSession.fromMap).toList();
  }

  static Future<void> addMessage(
    int sessionId, {
    required String role,
    required String content,
  }) async {
    final message = StoredMessage(
      sessionId: sessionId,
      role: role,
      content: content,
      createdAt: DateTime.now(),
    );
    if (kIsWeb) {
      await _webLoad();
      (_webMessages[sessionId] ??= []).add(message);
      await _webSaveMessages();
      await touchSession(sessionId);
      return;
    }
    final db = await _open();
    await db.insert('messages', message.toMap());
    await touchSession(sessionId);
  }

  /// All messages of a session, oldest first.
  static Future<List<StoredMessage>> listMessages(int sessionId) async {
    if (kIsWeb) {
      await _webLoad();
      return List.of(_webMessages[sessionId] ?? const []);
    }
    final db = await _open();
    final rows = await db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    return rows.map(StoredMessage.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // Android (SQLite)
  // ---------------------------------------------------------------------------

  static Future<Database> _open() async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'mindspark_chats.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (session_id) REFERENCES sessions (id)
          )
        ''');
      },
    );
    return _db!;
  }

  // ---------------------------------------------------------------------------
  // Web (local storage via shared_preferences)
  // ---------------------------------------------------------------------------

  static const _webSessionsKey = 'mindspark_chat_sessions';
  static const _webMessagesKey = 'mindspark_chat_messages';

  static Future<void> _webLoad() async {
    if (_webSessions != null) return;
    final prefs = await SharedPreferences.getInstance();
    final rawSessions = prefs.getString(_webSessionsKey);
    final rawMessages = prefs.getString(_webMessagesKey);

    _webSessions = [
      if (rawSessions != null)
        for (final item in (jsonDecode(rawSessions) as List))
          ChatSession.fromJson(item as Map<String, dynamic>),
    ];
    if (rawMessages != null) {
      final decoded = jsonDecode(rawMessages) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        _webMessages[int.parse(entry.key)] = [
          for (final item in (entry.value as List))
            StoredMessage.fromMap(item as Map<String, dynamic>),
        ];
      }
    }
    _webNextId = _webSessions!.fold(0, (max, s) => s.id > max ? s.id : max) + 1;
  }

  static Future<void> _webMutateSessions(
    void Function(List<ChatSession>) mutate,
  ) async {
    await _webLoad();
    mutate(_webSessions!);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _webSessionsKey,
      jsonEncode([for (final s in _webSessions!) s.toJson()]),
    );
  }

  static Future<void> _webSaveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _webMessagesKey,
      jsonEncode({
        for (final entry in _webMessages.entries)
          entry.key.toString(): [for (final m in entry.value) m.toMap()],
      }),
    );
  }

  static Future<int> _webCreateSession(String title) async {
    await _webLoad();
    final session = ChatSession(id: _webNextId++, title: title, updatedAt: DateTime.now());
    _webSessions!.insert(0, session);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _webSessionsKey,
      jsonEncode([for (final s in _webSessions!) s.toJson()]),
    );
    return session.id;
  }
}
