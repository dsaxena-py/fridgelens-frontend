import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sign-in with Supabase Auth (email + password). Widget tests swap in a fake.
abstract class AuthService extends ChangeNotifier {
  bool get signedIn;
  String? get email;
  Future<String?> accessToken();
  Future<void> signIn(String email, String password);

  /// Returns true when the account still needs its email confirmed before signing in.
  Future<bool> signUp(String email, String password, {String? displayName});
  Future<void> signOut();
}

class AuthFailure implements Exception {
  AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class SupabaseAuthService extends AuthService {
  SupabaseAuthService(this._auth) {
    _sub = _auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  final GoTrueClient _auth;
  late final StreamSubscription<AuthState> _sub;

  @override
  bool get signedIn => _auth.currentSession != null;

  @override
  String? get email => _auth.currentUser?.email;

  @override
  Future<String?> accessToken() async {
    final session = _auth.currentSession;
    if (session == null) return null;
    if (session.isExpired) {
      try {
        return (await _auth.refreshSession()).session?.accessToken;
      } on AuthException {
        return null;
      }
    }
    return session.accessToken;
  }

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  @override
  Future<bool> signUp(String email, String password, {String? displayName}) async {
    try {
      final r = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {if (displayName != null && displayName.trim().isNotEmpty) 'display_name': displayName.trim()},
      );
      return r.session == null;
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  String _friendly(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return "That email and password don't match. Try again.";
    if (m.contains('not confirmed')) return 'Confirm your email first. The link is in your inbox.';
    if (m.contains('already registered')) return 'There is already an account with that email. Sign in instead.';
    if (m.contains('password')) return e.message;
    return "We couldn't sign you in. Check your connection and try again.";
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
