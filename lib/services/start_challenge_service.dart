import 'mock_payment_service.dart';

class StartedChallenge {
  const StartedChallenge({
    required this.id,
    required this.paymentId,
    required this.amount,
    required this.status,
    required this.autoStartAt,
    required this.deadline,
    required this.startedAt,
    required this.createdAt,
  });

  factory StartedChallenge.fromJson(Object? data) {
    if (data is! Map) throw const FormatException('Invalid start response.');
    final json = Map<String, dynamic>.from(data);
    final values = [
      json['id'],
      json['payment_id'],
      json['amount'],
      json['status'],
      json['auto_start_at'],
      json['deadline'],
      json['started_at'],
      json['created_at'],
    ];
    if (values[0] is! String ||
        values[1] is! String ||
        values[2] is! int ||
        values[3] is! String ||
        values.skip(4).any((value) => value is! String)) {
      throw const FormatException('Invalid start response.');
    }
    return StartedChallenge(
      id: values[0] as String,
      paymentId: values[1] as String,
      amount: values[2] as int,
      status: values[3] as String,
      autoStartAt: DateTime.parse(values[4] as String),
      deadline: DateTime.parse(values[5] as String),
      startedAt: DateTime.parse(values[6] as String),
      createdAt: DateTime.parse(values[7] as String),
    );
  }

  final String id;
  final String paymentId;
  final int amount;
  final String status;
  final DateTime autoStartAt;
  final DateTime deadline;
  final DateTime startedAt;
  final DateTime createdAt;
}

class StartChallengeApiException implements Exception {
  const StartChallengeApiException({
    required this.statusCode,
    required this.code,
    required this.userMessage,
  });

  factory StartChallengeApiException.fromResponse({
    required int statusCode,
    required Object? body,
  }) {
    final code = body is Map && body['error_code'] is String
        ? body['error_code'] as String
        : 'internal_error';
    return StartChallengeApiException(
      statusCode: statusCode,
      code: code,
      userMessage: _messageFor(code),
    );
  }

  final int statusCode;
  final String code;
  final String userMessage;

  @override
  String toString() =>
      'StartChallengeApiException(statusCode: $statusCode, code: $code)';
}

String _messageFor(String code) {
  switch (code) {
    case 'unauthorized':
      return 'ログインが必要です。';
    case 'challenge_not_found':
      return 'Challengeが見つかりません。';
    case 'challenge_already_success':
      return '完了済みのChallengeは開始できません。';
    case 'challenge_already_failed':
      return '失敗したChallengeは開始できません。';
    case 'deadline_exceeded':
      return '期限を過ぎたため開始できません。';
    case 'idempotency_key_reused':
      return 'Challenge開始が重複しています。もう一度お試しください。';
    case 'invalid_uuid':
    case 'invalid_idempotency_key':
    case 'unknown_field':
      return 'Challengeの開始情報が正しくありません。';
    case 'start_challenge_conflict':
      return 'Challenge開始が競合しました。もう一度お試しください。';
    case 'temporary_unavailable':
      return 'Challengeサービスが一時的に利用できません。';
    default:
      return 'Challengeを開始できませんでした。';
  }
}

class StartChallengeService {
  StartChallengeService({
    MockPaymentFunctionInvoker? invoker,
    IdempotencyKeyGenerator? keyGenerator,
  }) : _invoker = invoker ?? SupabaseMockPaymentFunctionInvoker(),
       _keyGenerator = keyGenerator ?? UuidV4IdempotencyKeyGenerator();

  final MockPaymentFunctionInvoker _invoker;
  final IdempotencyKeyGenerator _keyGenerator;

  Future<StartedChallenge> start(String challengeId) async {
    try {
      final response = await _invoker.invoke(
        'start-challenge',
        body: {
          'challenge_id': challengeId,
          'idempotency_key': _keyGenerator.generate(),
        },
      );
      if (response.statusCode != 200) {
        throw StartChallengeApiException.fromResponse(
          statusCode: response.statusCode,
          body: response.data,
        );
      }
      return StartedChallenge.fromJson(response.data);
    } on StartChallengeApiException {
      rethrow;
    } on FormatException {
      throw const StartChallengeApiException(
        statusCode: 0,
        code: 'internal_error',
        userMessage: 'Challenge開始の応答を解釈できませんでした。',
      );
    } catch (_) {
      throw const StartChallengeApiException(
        statusCode: 0,
        code: 'internal_error',
        userMessage: 'Challenge開始サービスに接続できませんでした。',
      );
    }
  }
}
