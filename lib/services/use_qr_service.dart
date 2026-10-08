import 'mock_payment_service.dart';

class UsedQrCode {
  const UsedQrCode({
    required this.id,
    required this.challengeId,
    required this.status,
    this.usedAt,
  });

  factory UsedQrCode.fromJson(Object? data) {
    if (data is! Map) throw const FormatException('Invalid qr_code payload.');
    final json = Map<String, dynamic>.from(data);
    final id = json['id'];
    final challengeId = json['challenge_id'];
    final status = json['status'];
    if (id is! String || challengeId is! String || status is! String) {
      throw const FormatException('Invalid qr_code payload.');
    }
    return UsedQrCode(
      id: id,
      challengeId: challengeId,
      status: status,
      usedAt: json['used_at'] is String
          ? DateTime.tryParse(json['used_at'] as String)
          : null,
    );
  }

  final String id;
  final String challengeId;
  final String status;
  final DateTime? usedAt;
}

class UseQrResponse {
  const UseQrResponse({required this.result, this.qrCode});

  factory UseQrResponse.fromJson(Object? data) {
    if (data is! Map) throw const FormatException('Invalid use-qr response.');
    final json = Map<String, dynamic>.from(data);
    final result = json['result'];
    if (result is! String) {
      throw const FormatException('Invalid use-qr response.');
    }
    final qrRaw = json['qr_code'];
    return UseQrResponse(
      result: result,
      qrCode: qrRaw != null ? UsedQrCode.fromJson(qrRaw) : null,
    );
  }

  final String result;
  final UsedQrCode? qrCode;
}

class UseQrApiException implements Exception {
  const UseQrApiException({
    required this.statusCode,
    required this.code,
    required this.userMessage,
  });

  factory UseQrApiException.fromResponse({
    required int statusCode,
    required Object? body,
  }) {
    final code = body is Map && body['error_code'] is String
        ? body['error_code'] as String
        : 'internal_error';
    return UseQrApiException(
      statusCode: statusCode,
      code: code,
      userMessage: userMessageForUseQrCode(code),
    );
  }

  final int statusCode;
  final String code;
  final String userMessage;

  @override
  String toString() =>
      'UseQrApiException(statusCode: $statusCode, code: $code)';
}

String userMessageForUseQrCode(String code) {
  switch (code) {
    case 'unauthorized':
      return 'ログインが必要です。';
    case 'invalid_token':
    case 'invalid_request':
    case 'unknown_field':
    case 'invalid_idempotency_key':
      return 'QRコードの内容が正しくありません。';
    case 'qr_not_found':
      return 'QRコードが見つかりません。';
    case 'challenge_not_success':
      return 'このQRはまだ利用できません。';
    case 'qr_already_used':
      return 'このQRはすでに利用済みです。';
    case 'idempotency_key_reused':
    case 'use_qr_conflict':
      return 'QR利用処理が重複しています。もう一度お試しください。';
    case 'temporary_unavailable':
      return 'QRサービスが一時的に利用できません。';
    case 'method_not_allowed':
      return 'QR利用処理を実行できません。';
    default:
      return 'QRを利用できませんでした。';
  }
}

class UseQrService {
  UseQrService({
    MockPaymentFunctionInvoker? invoker,
    IdempotencyKeyGenerator? keyGenerator,
  }) : _invoker = invoker ?? SupabaseMockPaymentFunctionInvoker(),
       _keyGenerator = keyGenerator ?? UuidV4IdempotencyKeyGenerator();

  final MockPaymentFunctionInvoker _invoker;
  final IdempotencyKeyGenerator _keyGenerator;

  Future<UseQrResponse> use({
    required String token,
    String? idempotencyKey,
  }) async {
    try {
      final key = idempotencyKey ?? _keyGenerator.generate();
      final response = await _invoker.invoke(
        'use-qr',
        body: {'token': token, 'idempotency_key': key},
      );
      if (response.statusCode != 200) {
        throw UseQrApiException.fromResponse(
          statusCode: response.statusCode,
          body: response.data,
        );
      }
      return UseQrResponse.fromJson(response.data);
    } on UseQrApiException {
      rethrow;
    } on FormatException {
      throw const UseQrApiException(
        statusCode: 0,
        code: 'internal_error',
        userMessage: 'QR利用の応答を解釈できませんでした。',
      );
    } catch (_) {
      throw const UseQrApiException(
        statusCode: 0,
        code: 'internal_error',
        userMessage: 'QRサービスに接続できませんでした。',
      );
    }
  }
}
