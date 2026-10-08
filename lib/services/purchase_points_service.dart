import 'mock_payment_service.dart';

class PurchaseResult {
  const PurchaseResult({
    required this.purchaseId,
    required this.itemName,
    required this.pointsUsed,
    required this.availablePoints,
  });

  factory PurchaseResult.fromJson(Object? data) {
    if (data is! Map) throw const FormatException('Invalid purchase response.');
    final json = Map<String, dynamic>.from(data);
    final purchase = json['purchase'];
    if (purchase is! Map) {
      throw const FormatException('Invalid purchase response.');
    }
    final purchaseMap = Map<String, dynamic>.from(purchase);
    final id = purchaseMap['id'];
    final itemName = purchaseMap['item_name'];
    final pointsUsed = purchaseMap['points_used'];
    final available = json['available_points'];
    if (id is! String ||
        itemName is! String ||
        pointsUsed is! int ||
        available is! int) {
      throw const FormatException('Invalid purchase response.');
    }
    return PurchaseResult(
      purchaseId: id,
      itemName: itemName,
      pointsUsed: pointsUsed,
      availablePoints: available,
    );
  }

  final String purchaseId;
  final String itemName;
  final int pointsUsed;
  final int availablePoints;
}

class PurchasePointsApiException implements Exception {
  const PurchasePointsApiException({
    required this.statusCode,
    required this.code,
    required this.userMessage,
  });

  factory PurchasePointsApiException.fromResponse({
    required int statusCode,
    required Object? body,
  }) {
    final code = body is Map && body['error_code'] is String
        ? body['error_code'] as String
        : 'internal_error';
    return PurchasePointsApiException(
      statusCode: statusCode,
      code: code,
      userMessage: userMessageForPurchaseCode(code),
    );
  }

  final int statusCode;
  final String code;
  final String userMessage;
}

String userMessageForPurchaseCode(String code) {
  switch (code) {
    case 'unauthorized':
      return 'ログインが必要です。';
    case 'invalid_catalog_item':
      return '交換できる商品が見つかりません。';
    case 'insufficient_balance':
      return 'ポイントが不足しています。';
    case 'idempotency_key_reused':
    case 'purchase_points_conflict':
      return '交換処理が重複しています。もう一度お試しください。';
    case 'temporary_unavailable':
      return '交換サービスが一時的に利用できません。';
    default:
      return 'ポイント交換に失敗しました。';
  }
}

class PurchasePointsService {
  PurchasePointsService({
    MockPaymentFunctionInvoker? invoker,
    IdempotencyKeyGenerator? keyGenerator,
  }) : _invoker = invoker ?? SupabaseMockPaymentFunctionInvoker(),
       _keyGenerator = keyGenerator ?? UuidV4IdempotencyKeyGenerator();

  final MockPaymentFunctionInvoker _invoker;
  final IdempotencyKeyGenerator _keyGenerator;

  Future<PurchaseResult> purchase({
    required String catalogItemId,
    String? idempotencyKey,
  }) async {
    try {
      final key = idempotencyKey ?? _keyGenerator.generate();
      final response = await _invoker.invoke(
        'purchase-points',
        body: {'catalog_item_id': catalogItemId, 'idempotency_key': key},
      );
      if (response.statusCode != 200) {
        throw PurchasePointsApiException.fromResponse(
          statusCode: response.statusCode,
          body: response.data,
        );
      }
      return PurchaseResult.fromJson(response.data);
    } on PurchasePointsApiException {
      rethrow;
    } on FormatException {
      throw const PurchasePointsApiException(
        statusCode: 0,
        code: 'internal_error',
        userMessage: '交換の応答を解釈できませんでした。',
      );
    } catch (_) {
      throw const PurchasePointsApiException(
        statusCode: 0,
        code: 'internal_error',
        userMessage: '交換サービスに接続できませんでした。',
      );
    }
  }
}
