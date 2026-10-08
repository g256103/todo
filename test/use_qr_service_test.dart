import 'package:flutter_test/flutter_test.dart';
import 'package:todo/services/mock_payment_service.dart';
import 'package:todo/services/use_qr_service.dart';

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
  String generate() => 'use-qr-key';
}

void main() {
  test('sends use-qr contract and parses used response', () async {
    final invoker = _FakeInvoker(
      MockPaymentFunctionResponse(
        statusCode: 200,
        data: {
          'result': 'used',
          'qr_code': {
            'id': 'qr-id',
            'challenge_id': 'challenge-id',
            'status': 'USED',
            'used_at': '2026-10-08T00:00:00Z',
          },
        },
      ),
    );
    final service = UseQrService(
      invoker: invoker,
      keyGenerator: _FixedKeyGenerator(),
    );
    final res = await service.use(token: 'scan-token');

    expect(invoker.functionName, 'use-qr');
    expect(invoker.body, {
      'token': 'scan-token',
      'idempotency_key': 'use-qr-key',
    });
    expect(res.result, 'used');
    expect(res.qrCode?.status, 'USED');
  });

  test('maps error response to UseQrApiException', () async {
    final invoker = _FakeInvoker(
      MockPaymentFunctionResponse(
        statusCode: 409,
        data: const {'error_code': 'qr_already_used'},
      ),
    );
    final service = UseQrService(invoker: invoker);

    expect(
      () => service.use(token: 't'),
      throwsA(
        isA<UseQrApiException>().having(
          (e) => e.code,
          'code',
          'qr_already_used',
        ),
      ),
    );
  });
}
