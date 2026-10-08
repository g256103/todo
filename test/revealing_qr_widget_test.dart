import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/qr/revealing_qr_widget.dart';

void main() {
  testWidgets('instantReveal calls onAllCompletedFinished for last task', (
    tester,
  ) async {
    var allDone = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RevealingQrWidget(
            challengeId: '22222222-2222-4222-8222-222222222222',
            taskStatuses: const ['COMPLETED'],
            justApprovedTaskIndex: 0,
            instantReveal: true,
            onAllCompletedFinished: () => allDone = true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(allDone, isTrue);
  });
}
