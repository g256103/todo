import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:todo/features/auth/auth_service.dart';
import 'package:todo/features/settings/settings_tab.dart';
import 'package:todo/features/settings/user_profile_repository.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super.forTesting();

  @override
  Future<void> signOut() async {}
}

class _FakeProfileRepository extends UserProfileRepository {
  _FakeProfileRepository({this.profile});

  final UserProfile? profile;

  @override
  Future<UserProfile?> fetchProfile() async => profile;

  @override
  Future<void> updateUserName(String userName) async {}
}

void main() {
  testWidgets('SettingsTab shows email, user name, and terms link', (
    tester,
  ) async {
    final session = Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: const User(
        id: 'user-1',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-10-08T00:00:00Z',
        email: 'user@example.com',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsTab(
            authService: _FakeAuthService(),
            session: session,
            profileRepository: _FakeProfileRepository(
              profile: const UserProfile(userName: 'テストユーザー'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('user@example.com'), findsOneWidget);
    expect(find.text('テストユーザー'), findsOneWidget);
    expect(find.text('利用規約を確認'), findsOneWidget);
    expect(find.text('ログアウト'), findsOneWidget);
  });
}
