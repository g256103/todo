import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  const UserProfile({required this.userName});

  final String userName;
}

class UserProfileRepository {
  UserProfileRepository({SupabaseClient? client}) : _providedClient = client;

  final SupabaseClient? _providedClient;
  SupabaseClient get _client => _providedClient ?? Supabase.instance.client;

  Future<UserProfile?> fetchProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client
        .from('users')
        .select('user_name')
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return UserProfile(userName: response['user_name'] as String? ?? 'ユーザー');
  }

  Future<void> updateUserName(String userName) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Not signed in');
    }

    await _client
        .from('users')
        .update({'user_name': userName.trim()})
        .eq('id', user.id);
  }
}
