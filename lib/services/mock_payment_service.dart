import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class MockPayment {
  const MockPayment({
    required this.id,
    required this.amount,
    required this.status,
    this.createdAt,
    this.paidAt,
  });

  factory MockPayment.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final amount = json['amount'];
    final status = json['status'];
    if (id is! String || amount is! int || status is! String) {
      throw const FormatException('Invalid payment response.');
    }

    return MockPayment(
      id: id,
      amount: amount,
      status: status,
      createdAt: _parseDateTime(json['created_at']),
      paidAt: _parseDateTime(json['paid_at']),
    );
  }

  final String id;
  final int amount;
  final String status;
  final DateTime? createdAt;
  final DateTime? paidAt;
}

DateTime? _parseDateTime(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('Invalid payment timestamp.');
  }
  return DateTime.parse(value);
}

class MockPaymentApiException implements Exception {
  const MockPaymentApiException({
    required this.statusCode,
    required this.code,
    required this.userMessage,
  });

  factory MockPaymentApiException.fromResponse({
    required int statusCode,
    required Object? body,
  }) {
    final code = _errorCodeFromBody(body);
    return MockPaymentApiException(
      statusCode: statusCode,
      code: code,
      userMessage: _userMessageFor(code),
    );
  }

  final int statusCode;
  final String code;
  final String userMessage;

  @override
  String toString() =>
      'MockPaymentApiException(statusCode: $statusCode, code: $code)';
}

String _errorCodeFromBody(Object? body) {
  if (body is Map) {
    final value = body['error_code'];
    if (value is String && value.isNotEmpty) return value;
  }
  return 'internal_error';
}

String _userMessageFor(String code) {
  switch (code) {
    case 'unauthorized':
      return 'ログインが必要です。';
    case 'malformed_json':
    case 'invalid_request':
    case 'unknown_field':
    case 'invalid_amount':
    case 'invalid_uuid':
    case 'invalid_idempotency_key':
      return '支払い情報が正しくありません。';
    case 'payment_not_found':
      return '支払い情報が見つかりません。';
    case 'payment_not_pending':
      return 'この支払いはすでに処理されています。';
    case 'idempotency_key_reused':
      return '支払い処理が重複しています。もう一度お試しください。';
    case 'payment_creation_conflict':
      return '支払いの作成が競合しました。もう一度お試しください。';
    case 'temporary_unavailable':
      return '支払いサービスが一時的に利用できません。';
    case 'method_not_allowed':
      return '支払い処理を実行できません。';
    case 'internal_error':
    default:
      return '支払い処理に失敗しました。';
  }
}

class MockPaymentFunctionResponse {
  const MockPaymentFunctionResponse({
    required this.statusCode,
    required this.data,
  });

  final int statusCode;
  final Object? data;
}

abstract interface class MockPaymentFunctionInvoker {
  Future<MockPaymentFunctionResponse> invoke(
    String functionName, {
    required Map<String, Object?> body,
  });
}

class SupabaseMockPaymentFunctionInvoker implements MockPaymentFunctionInvoker {
  SupabaseMockPaymentFunctionInvoker({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<MockPaymentFunctionResponse> invoke(
    String functionName, {
    required Map<String, Object?> body,
  }) async {
    final response = await _client.functions.invoke(functionName, body: body);
    return MockPaymentFunctionResponse(
      statusCode: response.status,
      data: response.data,
    );
  }
}

abstract interface class IdempotencyKeyGenerator {
  String generate();
}

class UuidV4IdempotencyKeyGenerator implements IdempotencyKeyGenerator {
  UuidV4IdempotencyKeyGenerator({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;

  @override
  String generate() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}

class MockPaymentService {
  MockPaymentService({
    MockPaymentFunctionInvoker? invoker,
    IdempotencyKeyGenerator? keyGenerator,
  }) : _invoker = invoker ?? SupabaseMockPaymentFunctionInvoker(),
       _keyGenerator = keyGenerator ?? UuidV4IdempotencyKeyGenerator();

  final MockPaymentFunctionInvoker _invoker;
  final IdempotencyKeyGenerator _keyGenerator;

  Future<MockPayment> create(int amount) async {
    final response = await _invoke(
      'mock-payment-create',
      {'amount': amount, 'idempotency_key': _keyGenerator.generate()},
      acceptedStatuses: const {200, 201},
    );
    return _parsePayment(response);
  }

  Future<MockPayment> success(String paymentId) async {
    final response = await _invoke(
      'mock-payment-success',
      {'payment_id': paymentId, 'idempotency_key': _keyGenerator.generate()},
      acceptedStatuses: const {200},
    );
    return _parsePayment(response);
  }

  Future<MockPayment> failure(String paymentId) async {
    final response = await _invoke(
      'mock-payment-failure',
      {'payment_id': paymentId, 'idempotency_key': _keyGenerator.generate()},
      acceptedStatuses: const {200},
    );
    return _parsePayment(response);
  }

  Future<MockPaymentFunctionResponse> _invoke(
    String functionName,
    Map<String, Object?> body, {
    required Set<int> acceptedStatuses,
  }) async {
    try {
      final response = await _invoker.invoke(functionName, body: body);
      if (!acceptedStatuses.contains(response.statusCode)) {
        throw MockPaymentApiException.fromResponse(
          statusCode: response.statusCode,
          body: response.data,
        );
      }
      return response;
    } on MockPaymentApiException {
      rethrow;
    } catch (_) {
      throw const MockPaymentApiException(
        statusCode: 0,
        code: 'internal_error',
        userMessage: '支払いサービスに接続できませんでした。',
      );
    }
  }

  MockPayment _parsePayment(MockPaymentFunctionResponse response) {
    try {
      final data = response.data;
      if (data is! Map) throw const FormatException();
      final payment = data['payment'];
      if (payment is! Map) throw const FormatException();
      return MockPayment.fromJson(Map<String, dynamic>.from(payment));
    } on FormatException {
      throw const MockPaymentApiException(
        statusCode: 0,
        code: 'internal_error',
        userMessage: '支払いサービスの応答を解釈できませんでした。',
      );
    } on TypeError {
      throw const MockPaymentApiException(
        statusCode: 0,
        code: 'internal_error',
        userMessage: '支払いサービスの応答を解釈できませんでした。',
      );
    }
  }
}
