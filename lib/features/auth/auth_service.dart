import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/server_clock.dart';

class AuthService {
  AuthService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  AuthService.forTesting() : _client = null;

  final SupabaseClient? _client;

  Session? get currentSession => _client?.auth.currentSession;

  Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream.empty();

  Future<bool> signInWithGoogle() {
    final client = _client;
    if (client == null) {
      throw StateError('AuthService is not configured for authentication.');
    }
    if (kIsWeb) {
      return client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Uri.base.toString(),
      );
    }
    return client.auth.signInWithOAuth(OAuthProvider.google);
  }

  Future<void> signOut() {
    final client = _client;
    if (client == null) {
      throw StateError('AuthService is not configured for authentication.');
    }
    serverClock.reset();
    return client.auth.signOut();
  }
}
