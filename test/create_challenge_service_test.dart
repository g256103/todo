import 'package:flutter_test/flutter_test.dart';
import 'package:todo/services/create_challenge_service.dart';
import 'package:todo/services/mock_payment_service.dart';

class _FakeInvoker implements MockPaymentFunctionInvoker {
  _FakeInvoker(this.response);

  final MockPaymentFunctionResponse response;
  Map<String, Object?>? body;

  @override
  Future<MockPaymentFunctionResponse> invoke(
    String functionName, {
    required Map<String, Object?> body,
  }) async {
    expect(functionName, 'create-challenge');
    this.body = body;
    return response;
  }
}

class _FixedKeyGenerator implements IdempotencyKeyGenerator {
  @override
  String generate() => 'challenge-key';
}

Map<String, dynamic> _response() {
  return {
    'challenge': {
      'id': '22222222-2222-4222-8222-222222222222',
      'payment_id': '11111111-1111-4111-8111-111111111111',
      'amount': 1000,
      'status': 'WAITING',
      'auto_start_at': '2026-10-06T03:05:00Z',
      'deadline': '2026-10-07T03:00:00Z',
    },
    'challenge_tasks': [
      {
        'id': '33333333-3333-4333-8333-333333333333',
        'task_id': '44444444-4444-4444-8444-444444444444',
        'task_name_snapshot': 'Snapshot task',
        'sort_order': 0,
        'status': 'INCOMPLETE',
      },
    ],
  };
}

void main() {
  test('sends only the create-challenge contract and parses 201', () async {
    final invoker = _FakeInvoker(
      MockPaymentFunctionResponse(statusCode: 201, data: _response()),
    );
    final challenge =
        await CreateChallengeService(
          invoker: invoker,
          keyGenerator: _FixedKeyGenerator(),
        ).create(
          paymentId: '11111111-1111-4111-8111-111111111111',
          taskIds: const ['44444444-4444-4444-8444-444444444444'],
          routineIds: const ['55555555-5555-4555-8555-555555555555'],
        );

    expect(challenge.status, 'WAITING');
    expect(challenge.challengeTasks.single.taskNameSnapshot, 'Snapshot task');
    expect(invoker.body, {
      'payment_id': '11111111-1111-4111-8111-111111111111',
      'task_ids': ['44444444-4444-4444-8444-444444444444'],
      'routine_ids': ['55555555-5555-4555-8555-555555555555'],
      'idempotency_key': 'challenge-key',
    });
  });

  test('accepts 200 idempotent replay', () async {
    final challenge =
        await CreateChallengeService(
          invoker: _FakeInvoker(
            MockPaymentFunctionResponse(statusCode: 200, data: _response()),
          ),
          keyGenerator: _FixedKeyGenerator(),
        ).create(
          paymentId: '11111111-1111-4111-8111-111111111111',
          taskIds: const [],
          routineIds: const ['55555555-5555-4555-8555-555555555555'],
        );

    expect(challenge.id, '22222222-2222-4222-8222-222222222222');
  });

  for (final status in [401, 404, 409, 422, 503, 500]) {
    test('maps HTTP $status and error code', () async {
      final invoker = _FakeInvoker(
        MockPaymentFunctionResponse(
          statusCode: status,
          data: {'error_code': 'challenge_creation_conflict'},
        ),
      );
      expect(
        () => CreateChallengeService(invoker: invoker).create(
          paymentId: '11111111-1111-4111-8111-111111111111',
          taskIds: const [],
          routineIds: const ['55555555-5555-4555-8555-555555555555'],
        ),
        throwsA(
          isA<CreateChallengeApiException>()
              .having((error) => error.statusCode, 'statusCode', status)
              .having(
                (error) => error.code,
                'code',
                'challenge_creation_conflict',
              ),
        ),
      );
    });
  }
}
