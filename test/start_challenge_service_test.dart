import 'package:flutter_test/flutter_test.dart';
import 'package:todo/services/mock_payment_service.dart';
import 'package:todo/services/start_challenge_service.dart';

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
  String generate() => 'start-key';
}

Map<String, dynamic> _response() => {
  'id': '11111111-1111-4111-8111-111111111111',
  'payment_id': '22222222-2222-4222-8222-222222222222',
  'amount': 1000,
  'status': 'IN_PROGRESS',
  'auto_start_at': '2026-10-06T03:05:00Z',
  'deadline': '2026-10-07T03:00:00Z',
  'started_at': '2026-10-06T03:01:00Z',
  'created_at': '2026-10-06T03:00:00Z',
};

void main() {
  test('sends the start contract and parses the server response', () async {
    final invoker = _FakeInvoker(
      MockPaymentFunctionResponse(statusCode: 200, data: _response()),
    );
    final result = await StartChallengeService(
      invoker: invoker,
      keyGenerator: _FixedKeyGenerator(),
    ).start('11111111-1111-4111-8111-111111111111');

    expect(invoker.functionName, 'start-challenge');
    expect(invoker.body, {
      'challenge_id': '11111111-1111-4111-8111-111111111111',
      'idempotency_key': 'start-key',
    });
    expect(result.status, 'IN_PROGRESS');
    expect(result.startedAt, DateTime.utc(2026, 10, 6, 3, 1));
  });

  for (final status in [401, 404, 409, 422, 503, 500]) {
    test('maps HTTP $status', () async {
      expect(
        () => StartChallengeService(
          invoker: _FakeInvoker(
            MockPaymentFunctionResponse(
              statusCode: status,
              data: {'error_code': 'deadline_exceeded'},
            ),
          ),
        ).start('11111111-1111-4111-8111-111111111111'),
        throwsA(
          isA<StartChallengeApiException>()
              .having((error) => error.statusCode, 'statusCode', status)
              .having((error) => error.code, 'code', 'deadline_exceeded'),
        ),
      );
    });
  }
}
