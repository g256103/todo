import 'package:flutter_test/flutter_test.dart';
import 'package:todo/services/mock_payment_service.dart';

class _FakeInvoker implements MockPaymentFunctionInvoker {
  _FakeInvoker(this.responses);

  final List<MockPaymentFunctionResponse> responses;
  final calls = <({String name, Map<String, Object?> body})>[];

  @override
  Future<MockPaymentFunctionResponse> invoke(
    String functionName, {
    required Map<String, Object?> body,
  }) async {
    calls.add((name: functionName, body: body));
    return responses.removeAt(0);
  }
}

class _FakeKeyGenerator implements IdempotencyKeyGenerator {
  _FakeKeyGenerator(this.keys);

  final List<String> keys;

  @override
  String generate() => keys.removeAt(0);
}

class _ThrowingInvoker implements MockPaymentFunctionInvoker {
  @override
  Future<MockPaymentFunctionResponse> invoke(
    String functionName, {
    required Map<String, Object?> body,
  }) {
    throw StateError('connection failed');
  }
}

Map<String, dynamic> _payment({
  String id = '11111111-1111-4111-8111-111111111111',
  int amount = 1000,
  String status = 'PENDING',
}) {
  return {
    'id': id,
    'amount': amount,
    'status': status,
    'created_at': '2026-10-06T02:00:00Z',
    if (status == 'SUCCESS') 'paid_at': '2026-10-06T02:01:00Z',
  };
}

MockPaymentService service(
  MockPaymentFunctionResponse response, {
  String key = 'key-1',
}) {
  return MockPaymentService(
    invoker: _FakeInvoker([response]),
    keyGenerator: _FakeKeyGenerator([key]),
  );
}

void main() {
  test(
    'create sends amount and an operation-specific idempotency key',
    () async {
      final invoker = _FakeInvoker([
        MockPaymentFunctionResponse(
          statusCode: 201,
          data: {'payment': _payment()},
        ),
      ]);
      final result = await MockPaymentService(
        invoker: invoker,
        keyGenerator: _FakeKeyGenerator(['create-key']),
      ).create(1000);

      expect(result.amount, 1000);
      expect(result.status, 'PENDING');
      expect(invoker.calls.single.name, 'mock-payment-create');
      expect(invoker.calls.single.body, {
        'amount': 1000,
        'idempotency_key': 'create-key',
      });
    },
  );

  test('create accepts an idempotent replay response with HTTP 200', () async {
    final result = await service(
      MockPaymentFunctionResponse(
        statusCode: 200,
        data: {'payment': _payment()},
      ),
    ).create(1000);

    expect(result.id, '11111111-1111-4111-8111-111111111111');
  });

  test('success sends payment id and a separate key', () async {
    final invoker = _FakeInvoker([
      MockPaymentFunctionResponse(
        statusCode: 200,
        data: {'payment': _payment(status: 'SUCCESS')},
      ),
    ]);
    final result = await MockPaymentService(
      invoker: invoker,
      keyGenerator: _FakeKeyGenerator(['success-key']),
    ).success('11111111-1111-4111-8111-111111111111');

    expect(result.status, 'SUCCESS');
    expect(invoker.calls.single.name, 'mock-payment-success');
    expect(invoker.calls.single.body['idempotency_key'], 'success-key');
  });

  test('failure sends payment id and a separate key', () async {
    final invoker = _FakeInvoker([
      MockPaymentFunctionResponse(
        statusCode: 200,
        data: {'payment': _payment(status: 'FAILED')},
      ),
    ]);
    final result = await MockPaymentService(
      invoker: invoker,
      keyGenerator: _FakeKeyGenerator(['failure-key']),
    ).failure('11111111-1111-4111-8111-111111111111');

    expect(result.status, 'FAILED');
    expect(invoker.calls.single.name, 'mock-payment-failure');
    expect(invoker.calls.single.body['idempotency_key'], 'failure-key');
  });

  test('generates a new key for each payment operation', () async {
    final invoker = _FakeInvoker([
      MockPaymentFunctionResponse(
        statusCode: 201,
        data: {'payment': _payment()},
      ),
      MockPaymentFunctionResponse(
        statusCode: 200,
        data: {'payment': _payment(status: 'SUCCESS')},
      ),
      MockPaymentFunctionResponse(
        statusCode: 200,
        data: {'payment': _payment(status: 'FAILED')},
      ),
    ]);
    final service = MockPaymentService(
      invoker: invoker,
      keyGenerator: _FakeKeyGenerator([
        'create-key',
        'success-key',
        'failure-key',
      ]),
    );

    await service.create(1000);
    await service.success('11111111-1111-4111-8111-111111111111');
    await service.failure('11111111-1111-4111-8111-111111111111');

    expect(invoker.calls.map((call) => call.body['idempotency_key']), [
      'create-key',
      'success-key',
      'failure-key',
    ]);
  });

  test('generates canonical UUID v4 idempotency keys', () {
    final key = UuidV4IdempotencyKeyGenerator().generate();
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(key),
      isTrue,
    );
  });

  test('maps all documented HTTP error responses', () async {
    const cases = <({int status, String code})>[
      (status: 400, code: 'malformed_json'),
      (status: 401, code: 'unauthorized'),
      (status: 404, code: 'payment_not_found'),
      (status: 409, code: 'payment_not_pending'),
      (status: 422, code: 'invalid_amount'),
      (status: 503, code: 'temporary_unavailable'),
      (status: 500, code: 'internal_error'),
    ];

    for (final testCase in cases) {
      final error = await _captureError(
        service(
          MockPaymentFunctionResponse(
            statusCode: testCase.status,
            data: {'error_code': testCase.code},
          ),
        ).create(1000),
      );
      expect(error.statusCode, testCase.status);
      expect(error.code, testCase.code);
      expect(error.userMessage, isNotEmpty);
    }
  });

  test('maps unknown or non-JSON errors to internal_error', () async {
    final error = await _captureError(
      service(
        const MockPaymentFunctionResponse(statusCode: 500, data: 'failure'),
      ).create(1000),
    );

    expect(error.code, 'internal_error');
    expect(error.statusCode, 500);
  });

  test('maps transport failures to a user-facing internal error', () async {
    final error = await _captureError(
      MockPaymentService(
        invoker: _ThrowingInvoker(),
        keyGenerator: _FakeKeyGenerator(['create-key']),
      ).create(1000),
    );

    expect(error.statusCode, 0);
    expect(error.code, 'internal_error');
    expect(error.userMessage, '支払いサービスに接続できませんでした。');
  });

  test('rejects malformed successful response', () async {
    final error = await _captureError(
      service(
        const MockPaymentFunctionResponse(
          statusCode: 201,
          data: {'payment': {}},
        ),
      ).create(1000),
    );

    expect(error.code, 'internal_error');
  });
}

Future<MockPaymentApiException> _captureError(
  Future<MockPayment> request,
) async {
  try {
    await request;
    fail('Expected MockPaymentApiException');
  } on MockPaymentApiException catch (error) {
    return error;
  }
}
