import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/tasks/battery_hold_to_complete_tile.dart';
import 'package:todo/services/mock_payment_service.dart';

class _SequenceKeyGenerator implements IdempotencyKeyGenerator {
  _SequenceKeyGenerator();

  int _n = 0;

  @override
  String generate() => 'idempotency-key-${++_n}';
}

void main() {
  final fixedNow = DateTime.utc(2026, 10, 8, 12, 0, 0);

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
            deadline: fixedNow.add(const Duration(hours: 1)),
            now: () => fixedNow,
            onComplete: (_) async => true,
          ),
        ),
      ),
    );

    expect(find.text('テストタスク1'), findsOneWidget);
    expect(find.text('4秒長押しで完了'), findsOneWidget);
  });

  testWidgets('long press for 4 seconds triggers onComplete with hold key', (
    tester,
  ) async {
    var completedCalled = false;
    String? capturedKey;
    final keyGenerator = _SequenceKeyGenerator();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatteryHoldToCompleteTile(
            taskId: 'task-1',
            taskName: 'テストタスク1',
            isCompleted: false,
            deadline: fixedNow.add(const Duration(hours: 1)),
            now: () => fixedNow,
            idempotencyKeyGenerator: keyGenerator,
            onComplete: (key) async {
              completedCalled = true;
              capturedKey = key;
              return true;
            },
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('テストタスク1')),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('長押し中...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(completedCalled, isTrue);
    expect(capturedKey, 'idempotency-key-1');
    await gesture.up();
  });

  testWidgets('releasing before 4 seconds resets hold progress', (
    tester,
  ) async {
    var completedCalled = false;
    final keyGenerator = _SequenceKeyGenerator();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatteryHoldToCompleteTile(
            taskId: 'task-1',
            taskName: 'テストタスク1',
            isCompleted: false,
            deadline: fixedNow.add(const Duration(hours: 1)),
            now: () => fixedNow,
            idempotencyKeyGenerator: keyGenerator,
            onComplete: (_) async {
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

    await gesture.up();
    await tester.pumpAndSettle();

    expect(completedCalled, isFalse);
    expect(find.text('4秒長押しで完了'), findsOneWidget);
  });

  testWidgets('second hold after cancel uses a new idempotency key', (
    tester,
  ) async {
    final keys = <String>[];
    final keyGenerator = _SequenceKeyGenerator();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatteryHoldToCompleteTile(
            taskId: 'task-1',
            taskName: 'テストタスク1',
            isCompleted: false,
            deadline: fixedNow.add(const Duration(hours: 1)),
            now: () => fixedNow,
            idempotencyKeyGenerator: keyGenerator,
            onComplete: (key) async {
              keys.add(key);
              return true;
            },
          ),
        ),
      ),
    );

    Future<void> shortHold() async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('テストタスク1')),
      );
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await shortHold();
    expect(keys, isEmpty);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('テストタスク1')),
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await gesture.up();

    expect(keys, ['idempotency-key-2']);
  });

  testWidgets('app background during hold resets progress', (tester) async {
    var completedCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatteryHoldToCompleteTile(
            taskId: 'task-1',
            taskName: 'テストタスク1',
            isCompleted: false,
            deadline: fixedNow.add(const Duration(hours: 1)),
            now: () => fixedNow,
            onComplete: (_) async {
              completedCalled = true;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.startGesture(tester.getCenter(find.text('テストタスク1')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('長押し中...'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect(completedCalled, isFalse);
    expect(find.text('4秒長押しで完了'), findsOneWidget);
  });

  testWidgets('blocks long press when under 5 seconds to deadline', (
    tester,
  ) async {
    var completedCalled = false;
    final deadline = fixedNow.add(const Duration(seconds: 4));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatteryHoldToCompleteTile(
            taskId: 'task-1',
            taskName: 'テストタスク1',
            isCompleted: false,
            deadline: deadline,
            now: () => fixedNow,
            onComplete: (_) async {
              completedCalled = true;
              return true;
            },
          ),
        ),
      ),
    );

    expect(find.text('締切直前のため操作不可'), findsOneWidget);

    await tester.startGesture(tester.getCenter(find.text('テストタスク1')));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(completedCalled, isFalse);
    expect(find.textContaining('長押し中...'), findsNothing);
  });

  testWidgets('exclusive lock prevents second tile from starting hold', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              BatteryHoldToCompleteTile(
                taskId: 'task-1',
                taskName: 'タスクA',
                isCompleted: false,
                deadline: fixedNow.add(const Duration(hours: 1)),
                now: () => fixedNow,
                isExclusiveLocked: false,
                onComplete: (_) async => true,
              ),
              BatteryHoldToCompleteTile(
                taskId: 'task-2',
                taskName: 'タスクB',
                isCompleted: false,
                deadline: fixedNow.add(const Duration(hours: 1)),
                now: () => fixedNow,
                isExclusiveLocked: true,
                onComplete: (_) async => true,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.startGesture(tester.getCenter(find.text('タスクB')));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.textContaining('長押し中...'), findsNothing);
    expect(find.text('4秒長押しで完了'), findsNWidgets(2));
  });

  testWidgets('semantics confirm action opens dialog and completes task', (
    tester,
  ) async {
    var completedCalled = false;
    String? capturedKey;
    final keyGenerator = _SequenceKeyGenerator();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatteryHoldToCompleteTile(
            taskId: 'task-1',
            taskName: 'テストタスク1',
            isCompleted: false,
            deadline: fixedNow.add(const Duration(hours: 1)),
            now: () => fixedNow,
            idempotencyKeyGenerator: keyGenerator,
            onComplete: (key) async {
              completedCalled = true;
              capturedKey = key;
              return true;
            },
          ),
        ),
      ),
    );

    tester.semantics.tap(find.semantics.byLabel('テストタスク1 4秒長押しで完了'));
    await tester.pumpAndSettle();

    expect(find.text('タスクの完了'), findsOneWidget);
    await tester.tap(find.text('完了する'));
    await tester.pumpAndSettle();

    expect(completedCalled, isTrue);
    expect(capturedKey, 'idempotency-key-1');
  });

  testWidgets('accessibility icon dialog can complete task', (tester) async {
    var completedCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatteryHoldToCompleteTile(
            taskId: 'task-1',
            taskName: 'テストタスク1',
            isCompleted: false,
            deadline: fixedNow.add(const Duration(hours: 1)),
            now: () => fixedNow,
            onComplete: (_) async {
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

  testWidgets(
    'onComplete returning false after unmounted does not show success',
    (tester) async {
      final completer = Completer<bool>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatteryHoldToCompleteTile(
              taskId: 'task-1',
              taskName: 'テストタスク1',
              isCompleted: false,
              deadline: fixedNow.add(const Duration(hours: 1)),
              now: () => fixedNow,
              onComplete: (_) => completer.future,
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('テストタスク1')),
      );
      await tester.pump(const Duration(seconds: 4));
      expect(find.textContaining('長押し中...'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      completer.complete(false);
      await tester.pumpAndSettle();

      await gesture.up();
    },
  );
}
