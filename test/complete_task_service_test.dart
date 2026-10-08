import 'package:flutter_test/flutter_test.dart';
import 'package:todo/services/complete_task_service.dart';
import 'package:todo/services/mock_payment_service.dart';

class _FakeInvoker implements MockPaymentFunctionInvoker {
  _FakeInvoker(this.response);

  final MockPaymentFunctionResponse response;
  String? functionName;
  Map<String, Object?>? body;

  @override
  Future<MockPaymentFunctionResponse> invoke(
    String functionName, {
    required Map<String, Object?> body,
  }) async {
    this.functionName = functionName;
    this.body = body;
    return response;
  }
}

class _FixedKeyGenerator implements IdempotencyKeyGenerator {
  @override
  String generate() => 'complete-key';
}

Map<String, dynamic> _response({
  String result = 'completed',
  String challengeStatus = 'IN_PROGRESS',
}) => {
  'result': result,
  'challenge_task': {
    'id': '33333333-3333-4333-8333-333333333333',
    'challenge_id': '11111111-1111-4111-8111-111111111111',
    'status': 'COMPLETED',
    'completed_at': '2026-10-06T03:02:00Z',
  },
  'challenge_status': challengeStatus,
};

void main() {
  test('sends the complete-task contract and parses response', () async {
    final invoker = _FakeInvoker(
      MockPaymentFunctionResponse(statusCode: 200, data: _response()),
    );
    final service = CompleteTaskService(
      invoker: invoker,
      keyGenerator: _FixedKeyGenerator(),
    );
    final res = await service.complete(
      challengeTaskId: '33333333-3333-4333-8333-333333333333',
    );

    expect(invoker.functionName, 'complete-task');
    expect(invoker.body, {
      'challenge_task_id': '33333333-3333-4333-8333-333333333333',
      'idempotency_key': 'complete-key',
    });
    expect(res.result, 'completed');
    expect(res.task?.status, 'COMPLETED');
    expect(res.challengeStatus, 'IN_PROGRESS');
  });

  test('parses challenge_success when last task completed', () async {
    final invoker = _FakeInvoker(
      MockPaymentFunctionResponse(
        statusCode: 200,
        data: {
          ..._response(result: 'challenge_success', challengeStatus: 'SUCCESS'),
          'refunded': true,
          'refund_amount': 1000,
        },
      ),
    );
    final service = CompleteTaskService(
      invoker: invoker,
      keyGenerator: _FixedKeyGenerator(),
    );
    final res = await service.complete(
      challengeTaskId: '33333333-3333-4333-8333-333333333333',
    );

    expect(res.result, 'challenge_success');
    expect(res.challengeStatus, 'SUCCESS');
    expect(res.refunded, isTrue);
    expect(res.refundAmount, 1000);
  });

  test(
    'parses HTTP 200 deadline_exceeded as a result, not an exception',
    () async {
      final invoker = _FakeInvoker(
        MockPaymentFunctionResponse(
          statusCode: 200,
          data: {'result': 'deadline_exceeded'},
        ),
      );
      final service = CompleteTaskService(
        invoker: invoker,
        keyGenerator: _FixedKeyGenerator(),
      );
      final res = await service.complete(
        challengeTaskId: '33333333-3333-4333-8333-333333333333',
      );

      expect(res.result, 'deadline_exceeded');
      expect(res.task, isNull);
      expect(res.challengeStatus, isNull);
      expect(res.invalidStateErrorCode, isNull);
      expect(res.rejectionUserMessage, '期限を過ぎたため完了できません。');
    },
  );

  test('parses HTTP 200 invalid_state with diagnostic error_code', () async {
    final invoker = _FakeInvoker(
      MockPaymentFunctionResponse(
        statusCode: 200,
        data: {
          'result': 'invalid_state',
          'error_code': 'challenge_not_in_progress',
        },
      ),
    );
    final service = CompleteTaskService(
      invoker: invoker,
      keyGenerator: _FixedKeyGenerator(),
    );
    final res = await service.complete(
      challengeTaskId: '33333333-3333-4333-8333-333333333333',
    );

    expect(res.result, 'invalid_state');
    expect(res.invalidStateErrorCode, 'challenge_not_in_progress');
    expect(res.task, isNull);
    expect(res.challengeStatus, isNull);
    expect(res.rejectionUserMessage, '進行中のChallengeではありません。');
  });

  for (final status in [401, 404, 409, 422, 503, 500]) {
    test('maps HTTP $status to exception', () async {
      final invoker = _FakeInvoker(
        MockPaymentFunctionResponse(
          statusCode: status,
          data: {'error_code': 'unauthorized'},
        ),
      );
      expect(
        () => CompleteTaskService(
          invoker: invoker,
          keyGenerator: _FixedKeyGenerator(),
        ).complete(challengeTaskId: '33333333-3333-4333-8333-333333333333'),
        throwsA(isA<CompleteTaskApiException>()),
      );
    });
  }
}
