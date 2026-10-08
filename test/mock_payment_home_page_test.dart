import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/home/mock_payment_home_page.dart';
import 'package:todo/features/tasks/task_repository.dart';
import 'package:todo/features/routines/routine_repository.dart';
import 'package:todo/services/complete_task_service.dart';
import 'package:todo/services/create_challenge_service.dart';
import 'package:todo/services/mock_payment_service.dart';
import 'package:todo/services/start_challenge_service.dart';
import 'package:todo/features/qr/qr_repository.dart';

class _FakeInvoker implements MockPaymentFunctionInvoker {
  _FakeInvoker({
    this.completeTaskResult = 'challenge_success',
    this.completeTaskDelay,
  });

  final String completeTaskResult;
  final Duration? completeTaskDelay;
  int callCount = 0;
  final calls = <({String name, Map<String, Object?> body})>[];

  @override
  Future<MockPaymentFunctionResponse> invoke(
    String functionName, {
    required Map<String, Object?> body,
  }) async {
    callCount++;
    calls.add((name: functionName, body: body));
    if (functionName == 'create-challenge') {
      return MockPaymentFunctionResponse(
        statusCode: 201,
        data: {
          'challenge': {
            'id': '22222222-2222-4222-8222-222222222222',
            'payment_id': body['payment_id'],
            'amount': 1000,
            'status': 'WAITING',
            'auto_start_at': '2026-10-06T03:05:00Z',
            'deadline': '2099-01-01T03:00:00Z',
          },
          'challenge_tasks': [
            {
              'id': '33333333-3333-4333-8333-333333333333',
              'task_id': 'task-1',
              'task_name_snapshot': 'テストタスク',
              'sort_order': 0,
              'status': 'INCOMPLETE',
            },
          ],
        },
      );
    }
    if (functionName == 'start-challenge') {
      return MockPaymentFunctionResponse(
        statusCode: 200,
        data: {
          'id': body['challenge_id'],
          'payment_id': '11111111-1111-4111-8111-111111111111',
          'amount': 1000,
          'status': 'IN_PROGRESS',
          'auto_start_at': '2026-10-06T03:05:00Z',
          'deadline': '2099-01-01T03:00:00Z',
          'started_at': '2026-10-06T03:01:00Z',
          'created_at': '2026-10-06T03:00:00Z',
        },
      );
    }
    if (functionName == 'complete-task') {
      if (completeTaskDelay != null) {
        await Future<void>.delayed(completeTaskDelay!);
      }
      if (completeTaskResult == 'deadline_exceeded') {
        return MockPaymentFunctionResponse(
          statusCode: 200,
          data: const {'result': 'deadline_exceeded'},
        );
      }
      return MockPaymentFunctionResponse(
        statusCode: 200,
        data: {
          'result': 'challenge_success',
          'challenge_task': {
            'id': body['challenge_task_id'],
            'challenge_id': '22222222-2222-4222-8222-222222222222',
            'status': 'COMPLETED',
            'completed_at': '2026-10-06T03:02:00Z',
          },
          'challenge_status': 'SUCCESS',
        },
      );
    }
    final status = functionName == 'mock-payment-create'
        ? 'PENDING'
        : functionName == 'mock-payment-success'
        ? 'SUCCESS'
        : 'FAILED';
    return MockPaymentFunctionResponse(
      statusCode: functionName == 'mock-payment-create' ? 201 : 200,
      data: {
        'payment': {
          'id': '11111111-1111-4111-8111-111111111111',
          'amount': body['amount'] ?? 1000,
          'status': status,
        },
      },
    );
  }
}

class _FixedKeyGenerator implements IdempotencyKeyGenerator {
  @override
  String generate() => '11111111-1111-4111-8111-111111111111';
}

void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('creates and confirms payment through the service', (
    tester,
  ) async {
    _tallViewport(tester);
    final invoker = _FakeInvoker();
    final paymentService = MockPaymentService(
      invoker: invoker,
      keyGenerator: _FixedKeyGenerator(),
    );
    final challengeService = CreateChallengeService(
      invoker: invoker,
      keyGenerator: _FixedKeyGenerator(),
    );
    final startChallengeService = StartChallengeService(
      invoker: invoker,
      keyGenerator: _FixedKeyGenerator(),
    );
    final completeTaskService = CompleteTaskService(
      invoker: invoker,
      keyGenerator: _FixedKeyGenerator(),
    );
    final task = Task(
      id: 'task-1',
      userId: 'user-1',
      name: 'テストタスク',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MockPaymentHomePage(
            paymentService: paymentService,
            challengeService: challengeService,
            startChallengeService: startChallengeService,
            completeTaskService: completeTaskService,
            qrLoader: (_) async => const QrCodeRecord(
              id: 'qr-1',
              challengeId: '22222222-2222-4222-8222-222222222222',
              token: 'claim-token-abc',
              status: 'AVAILABLE',
            ),
            skipQrRevealAnimation: true,
            taskLoader: () async => [task],
            routineLoader: () async => const <Routine>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('¥1000 をコミットする'), findsOneWidget);
    await tester.tap(find.text('¥1000 をコミットする'));
    await tester.pumpAndSettle();
    expect(find.text('支払い成功'), findsOneWidget);
    expect(invoker.callCount, 1);

    await tester.tap(find.text('支払い成功'));
    await tester.pumpAndSettle();
    expect(find.text('PaymentがSUCCESSになりました。'), findsOneWidget);
    expect(invoker.callCount, 2);

    await tester.tap(find.text('Challengeを作成する'));
    await tester.pumpAndSettle();
    expect(find.text('Challenge作成完了'), findsOneWidget);
    expect(invoker.callCount, 3);
    expect(invoker.calls.last.name, 'create-challenge');
    expect(
      invoker.calls.last.body['payment_id'],
      '11111111-1111-4111-8111-111111111111',
    );
    expect(invoker.calls.last.body['task_ids'], ['task-1']);
    expect(invoker.calls.last.body['routine_ids'], <String>[]);

    await tester.tap(find.text('チャレンジ開始'));
    await tester.pumpAndSettle();
    expect(find.text('Challenge進行中'), findsOneWidget);
    expect(find.text('IN_PROGRESS'), findsOneWidget);
    expect(find.text('テストタスク'), findsOneWidget);
    expect(invoker.calls.last.name, 'start-challenge');

    // タスクを完了する（アクセシビリティダイアログ経由で完了）
    await tester.ensureVisible(find.byIcon(Icons.accessibility));
    await tester.tap(find.byIcon(Icons.accessibility));
    await tester.pumpAndSettle();
    expect(find.text('タスクの完了'), findsOneWidget);

    await tester.tap(find.text('完了する'));
    await tester.pumpAndSettle();

    expect(invoker.calls.last.name, 'complete-task');
    expect(
      invoker.calls.last.body['challenge_task_id'],
      '33333333-3333-4333-8333-333333333333',
    );
    expect(find.text('チャレンジ達成！ 🎉'), findsOneWidget);
    expect(find.textContaining('コミット金額 ¥1000 は全額返金されました。'), findsOneWidget);
  });

  testWidgets('shows message when complete-task returns deadline_exceeded', (
    tester,
  ) async {
    _tallViewport(tester);
    final invoker = _FakeInvoker(completeTaskResult: 'deadline_exceeded');
    final paymentService = MockPaymentService(
      invoker: invoker,
      keyGenerator: _FixedKeyGenerator(),
    );
    final challengeService = CreateChallengeService(
      invoker: invoker,
      keyGenerator: _FixedKeyGenerator(),
    );
    final startChallengeService = StartChallengeService(
      invoker: invoker,
      keyGenerator: _FixedKeyGenerator(),
    );
    final completeTaskService = CompleteTaskService(
      invoker: invoker,
      keyGenerator: _FixedKeyGenerator(),
    );
    final task = Task(
      id: 'task-1',
      userId: 'user-1',
      name: 'テストタスク',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MockPaymentHomePage(
            paymentService: paymentService,
            challengeService: challengeService,
            startChallengeService: startChallengeService,
            completeTaskService: completeTaskService,
            qrLoader: (_) async => const QrCodeRecord(
              id: 'qr-1',
              challengeId: '22222222-2222-4222-8222-222222222222',
              token: 'claim-token-abc',
              status: 'AVAILABLE',
            ),
            skipQrRevealAnimation: true,
            taskLoader: () async => [task],
            routineLoader: () async => const <Routine>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('¥1000 をコミットする'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('支払い成功'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Challengeを作成する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('チャレンジ開始'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.accessibility));
    await tester.tap(find.byIcon(Icons.accessibility));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完了する'));
    await tester.pumpAndSettle();

    expect(find.text('期限を過ぎたため完了できません。'), findsOneWidget);
  });

  testWidgets(
    'does not treat complete-task success when page unmounted mid-request',
    (tester) async {
      _tallViewport(tester);
      final invoker = _FakeInvoker(
        completeTaskDelay: const Duration(seconds: 1),
      );
      final paymentService = MockPaymentService(
        invoker: invoker,
        keyGenerator: _FixedKeyGenerator(),
      );
      final challengeService = CreateChallengeService(
        invoker: invoker,
        keyGenerator: _FixedKeyGenerator(),
      );
      final startChallengeService = StartChallengeService(
        invoker: invoker,
        keyGenerator: _FixedKeyGenerator(),
      );
      final completeTaskService = CompleteTaskService(
        invoker: invoker,
        keyGenerator: _FixedKeyGenerator(),
      );
      final task = Task(
        id: 'task-1',
        userId: 'user-1',
        name: 'テストタスク',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MockPaymentHomePage(
              paymentService: paymentService,
              challengeService: challengeService,
              startChallengeService: startChallengeService,
              completeTaskService: completeTaskService,
              taskLoader: () async => [task],
              routineLoader: () async => const <Routine>[],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('¥1000 をコミットする'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('支払い成功'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Challengeを作成する'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('チャレンジ開始'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.accessibility));
    await tester.tap(find.byIcon(Icons.accessibility));
      await tester.pumpAndSettle();
      await tester.tap(find.text('完了する'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 2));

      expect(invoker.calls.where((c) => c.name == 'complete-task').length, 1);
      expect(find.text('チャレンジ達成！ 🎉'), findsNothing);
    },
  );
}
