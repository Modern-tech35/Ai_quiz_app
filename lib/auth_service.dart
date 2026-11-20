import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

/// A Firebase Authentication failure, carrying Firebase's error code
/// (e.g. `email-already-in-use`, `invalid-credential`) so the UI can translate
/// it.
class AuthFailure implements Exception {
  const AuthFailure(this.code);

  final String code;

  @override
  String toString() => 'AuthFailure($code)';
}

/// A signed-in Firebase user.
@immutable
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
  });

  final String uid;
  final String email;
  final String? displayName;

  String get name =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!.trim()
          : email.split('@').first;

  String get initial {
    final source = name;
    return source.isEmpty ? '?' : source.substring(0, 1).toUpperCase();
  }

  factory AuthUser.fromFirebase(fb.User user) => AuthUser(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
      );
}

/// Email/password authentication backed by native Firebase Auth (project
/// `fir-paid`, configured through `android/app/google-services.json`).
///
/// [attach] starts observing Firebase's auth state after
/// `Firebase.initializeApp()`; sessions then restore automatically and every
/// sign-in/sign-out updates listeners.
class AuthService extends ChangeNotifier {
  AuthUser? _user;
  StreamSubscription<fb.User?>? _subscription;
  bool _busy = false;

  AuthUser? get user => _user;
  bool get signedIn => _user != null;
  bool get busy => _busy;

  /// Starts tracking the Firebase session. Call once after Firebase is ready.
  void attach() {
    if (_subscription != null) return;
    final auth = fb.FirebaseAuth.instance;
    _user = _map(auth.currentUser);
    _subscription = auth.authStateChanges().listen((user) {
      _user = _map(user);
      notifyListeners();
    });
  }

  Future<void> signIn({required String email, required String password}) {
    return _run(() async {
      await _guard(
        () => fb.FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) {
    return _run(() async {
      final credential = await _guard(
        () => fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

      final name = displayName?.trim() ?? '';
      final user = credential.user;
      if (name.isNotEmpty && user != null) {
        await _guard(() => user.updateDisplayName(name));
        await user.reload();
        _user = _map(fb.FirebaseAuth.instance.currentUser);
        notifyListeners();
      }
    });
  }

  Future<void> updateDisplayName(String name) async {
    final trimmed = name.trim();
    final current = fb.FirebaseAuth.instance.currentUser;
    if (current == null || trimmed.isEmpty || trimmed == current.displayName) {
      return;
    }

    await _run(() async {
      await _guard(() => current.updateDisplayName(trimmed));
      await current.reload();
      _user = _map(fb.FirebaseAuth.instance.currentUser);
      notifyListeners();
    });
  }

  Future<void> signOut() async {
    await fb.FirebaseAuth.instance.signOut();
    _user = null;
    notifyListeners();
  }

  AuthUser? _map(fb.User? user) => user == null ? null : AuthUser.fromFirebase(user);

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on fb.FirebaseAuthException catch (error) {
      throw AuthFailure(error.code);
    } catch (_) {
      throw const AuthFailure('unknown');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
