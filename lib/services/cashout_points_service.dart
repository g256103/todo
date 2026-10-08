import 'mock_payment_service.dart';

class CashoutResult {
  const CashoutResult({
    required this.cashoutId,
    required this.pointsUsed,
    required this.feePoints,
    required this.cashAmount,
    required this.availablePoints,
  });

  factory CashoutResult.fromJson(Object? data) {
    if (data is! Map) throw const FormatException('Invalid cashout response.');
    final json = Map<String, dynamic>.from(data);
    final cashout = json['cashout'];
    if (cashout is! Map) {
      throw const FormatException('Invalid cashout response.');
    }
    final cashoutMap = Map<String, dynamic>.from(cashout);
    final id = cashoutMap['id'];
    final pointsUsed = cashoutMap['points_used'];
    final feePoints = cashoutMap['fee_points'];
    final cashAmount = cashoutMap['cash_amount'];
    final available = json['available_points'];
    if (id is! String ||
        pointsUsed is! int ||
        feePoints is! int ||
        cashAmount is! int ||
        available is! int) {
      throw const FormatException('Invalid cashout response.');
    }
    return CashoutResult(
      cashoutId: id,
      pointsUsed: pointsUsed,
      feePoints: feePoints,
      cashAmount: cashAmount,
      availablePoints: available,
    );
  }

  final String cashoutId;
  final int pointsUsed;
  final int feePoints;
  final int cashAmount;
  final int availablePoints;
}

class CashoutPointsApiException implements Exception {
  const CashoutPointsApiException({
    required this.statusCode,
    required this.code,
    required this.userMessage,
  });

  factory CashoutPointsApiException.fromResponse({
    required int statusCode,
    required Object? body,
  }) {
    final code = body is Map && body['error_code'] is String
        ? body['error_code'] as String
        : 'internal_error';
    return CashoutPointsApiException(
      statusCode: statusCode,
      code: code,
      userMessage: userMessageForCashoutCode(code),
    );
  }

  final int statusCode;
  final String code;
  final String userMessage;
}

String userMessageForCashoutCode(String code) {
  switch (code) {
    case 'unauthorized':
      return 'ログインが必要です。';
    case 'invalid_points_used':
      return '出金ポイントは1000pt以上で10pt単位です。';
    case 'insufficient_balance':
      return 'ポイントが不足しています。';
    case 'cashout_not_eligible':
      return '現金化の条件（7回成功・1週間継続）を満たしていません。';
    case 'idempotency_key_reused':
    case 'cashout_points_conflict':
      return '出金処理が重複しています。もう一度お試しください。';
    case 'temporary_unavailable':
      return '出金サービスが一時的に利用できません。';
    default:
      return '現金化に失敗しました。';
  }
}

class CashoutPointsService {
  CashoutPointsService({
    MockPaymentFunctionInvoker? invoker,
    IdempotencyKeyGenerator? keyGenerator,
  }) : _invoker = invoker ?? SupabaseMockPaymentFunctionInvoker(),
       _keyGenerator = keyGenerator ?? UuidV4IdempotencyKeyGenerator();

  final MockPaymentFunctionInvoker _invoker;
  final IdempotencyKeyGenerator _keyGenerator;

  Future<CashoutResult> cashout({
    required int pointsUsed,
    String? idempotencyKey,
  }) async {
    try {
      final key = idempotencyKey ?? _keyGenerator.generate();
      final response = await _invoker.invoke(
        'cashout-points',
        body: {'points_used': pointsUsed, 'idempotency_key': key},
      );
      if (response.statusCode != 200) {
        throw CashoutPointsApiException.fromResponse(
          statusCode: response.statusCode,
          body: response.data,
        );
      }
      return CashoutResult.fromJson(response.data);
    } on CashoutPointsApiException {
      rethrow;
    } on FormatException {
      throw const CashoutPointsApiException(
        statusCode: 0,
        code: 'internal_error',
        userMessage: '出金の応答を解釈できませんでした。',
      );
    } catch (_) {
      throw const CashoutPointsApiException(
        statusCode: 0,
        code: 'internal_error',
        userMessage: '出金サービスに接続できませんでした。',
      );
    }
  }
}
