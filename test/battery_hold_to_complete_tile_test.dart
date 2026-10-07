import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/tasks/battery_hold_to_complete_tile.dart';

void main() {
  testWidgets('initial display shows task name and hold prompt', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatteryHoldToCompleteTile(
            taskId: 'task-1',
            taskName: 'テストタスク1',
            isCompleted: false,
            deadline: DateTime.now().add(const Duration(hours: 1)),
            onComplete: () async => true,
          ),
        ),
      ),
    );

    expect(find.text('テストタスク1'), findsOneWidget);
    expect(find.text('4秒長押しで完了'), findsOneWidget);
  });

  testWidgets('long press for 4 seconds triggers onComplete', (tester) async {
    var completedCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatteryHoldToCompleteTile(
            taskId: 'task-1',
            taskName: 'テストタスク1',
            isCompleted: false,
            deadline: DateTime.now().add(const Duration(hours: 1)),
            onComplete: () async {
              completedCalled = true;
              return true;
            },
          ),
        ),
      ),
    );

    // 長押し開始
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('テストタスク1')),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('長押し中...'), findsOneWidget);

    // 4秒経過
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(completedCalled, isTrue);
    await gesture.up();
  });

  testWidgets('releasing before 4 seconds resets hold progress', (
    tester,
  ) async {
    var completedCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatteryHoldToCompleteTile(
            taskId: 'task-1',
            taskName: 'テストタスク1',
            isCompleted: false,
            deadline: DateTime.now().add(const Duration(hours: 1)),
            onComplete: () async {
              completedCalled = true;
              return true;
            },
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('テストタスク1')),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('長押し中...'), findsOneWidget);

    // 指を離す
    await gesture.up();
    await tester.pumpAndSettle();

    expect(completedCalled, isFalse);
    expect(find.text('4秒長押しで完了'), findsOneWidget);
  });

  testWidgets('accessibility dialog can complete task', (tester) async {
    var completedCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatteryHoldToCompleteTile(
            taskId: 'task-1',
            taskName: 'テストタスク1',
            isCompleted: false,
            deadline: DateTime.now().add(const Duration(hours: 1)),
            onComplete: () async {
              completedCalled = true;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.accessibility));
    await tester.pumpAndSettle();

    expect(find.text('タスクの完了'), findsOneWidget);
    expect(find.text('「テストタスク1」を完了しますか？'), findsOneWidget);

    await tester.tap(find.text('完了する'));
    await tester.pumpAndSettle();

    expect(completedCalled, isTrue);
  });
}
