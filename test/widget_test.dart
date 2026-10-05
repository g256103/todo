import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/auth/auth_gate.dart';
import 'package:todo/features/auth/auth_service.dart';

void main() {
  testWidgets('未ログイン時にGoogleログイン画面を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(authService: AuthService.forTesting())),
    );

    expect(find.text('Googleでログイン'), findsOneWidget);
  });
}
