import 'mock_payment_service.dart';

class CompletedChallengeTask {
  const CompletedChallengeTask({
    required this.id,
    required this.challengeId,
    required this.status,
    required this.completedAt,
  });

  factory CompletedChallengeTask.fromJson(Object? data) {
    if (data is! Map) throw const FormatException('Invalid task payload.');
    final json = Map<String, dynamic>.from(data);
    final id = json['id'];
    final challengeId = json['challenge_id'];
    final status = json['status'];
    final completedAtRaw = json['completed_at'];

    if (id is! String || challengeId is! String || status is! String) {
      throw const FormatException('Invalid task payload.');
    }

    return CompletedChallengeTask(
      id: id,
      challengeId: challengeId,
      status: status,
      completedAt: completedAtRaw is String
          ? DateTime.tryParse(completedAtRaw)
          : null,
    );
  }

  final String id;
  final String challengeId;
  final String status;
  final DateTime? completedAt;
}

class CompleteTaskResponse {
  const CompleteTaskResponse({
    required this.result,
    required this.task,
    required this.challengeStatus,
  });

  factory CompleteTaskResponse.fromJson(Object? data) {
    if (data is! Map) throw const FormatException('Invalid complete response.');
    final json = Map<String, dynamic>.from(data);
    final result = json['result'];
    final challengeStatus = json['challenge_status'];
    final taskData = json['challenge_task'];

    if (result is! String || challengeStatus is! String || taskData == null) {
      throw const FormatException('Invalid complete response.');
    }

    return CompleteTaskResponse(
      result: result,
      task: CompletedChallengeTask.fromJson(taskData),
      challengeStatus: challengeStatus,
    );
  }

  final String
  result; // 'completed' | 'challenge_success' | 'already_completed'
  final CompletedChallengeTask task;
  final String challengeStatus; // 'IN_PROGRESS' | 'SUCCESS'
}

class CompleteTaskApiException implements Exception {
  const CompleteTaskApiException({
    required this.statusCode,
    required this.code,
    required this.userMessage,
  });

  factory CompleteTaskApiException.fromResponse({
    required int statusCode,
    required Object? body,
  }) {
    final code = body is Map && body['error_code'] is String
        ? body['error_code'] as String
        : 'internal_error';
    return CompleteTaskApiException(
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
      'CompleteTaskApiException(statusCode: $statusCode, code: $code)';
}

String _messageFor(String code) {
  switch (code) {
    case 'unauthorized':
      return 'ログインが必要です。';
    case 'task_not_found':
      return 'タスクが見つかりません。';
    case 'challenge_not_found':
      return 'Challengeが見つかりません。';
    case 'challenge_not_in_progress':
      return '進行中のChallengeではありません。';
    case 'challenge_already_success':
      return 'すでに完了したChallengeです。';
    case 'challenge_already_failed':
      return 'すでに終了したChallengeです。';
    case 'deadline_exceeded':
      return '期限を過ぎたため完了できません。';
    case 'idempotency_key_reused':
      return 'タスク完了処理が重複しています。もう一度お試しください。';
    case 'complete_task_conflict':
      return 'タスク完了処理が競合しました。もう一度お試しください。';
    case 'invalid_uuid':
    case 'invalid_idempotency_key':
    case 'unknown_field':
      return 'タスク完了情報が正しくありません。';
    case 'temporary_unavailable':
      return 'タスク完了サービスが一時的に利用できません。';
    default:
      return 'タスクを完了できませんでした。';
  }
}

class CompleteTaskService {
  CompleteTaskService({
    MockPaymentFunctionInvoker? invoker,
    IdempotencyKeyGenerator? keyGenerator,
  }) : _invoker = invoker ?? SupabaseMockPaymentFunctionInvoker(),
       _keyGenerator = keyGenerator ?? UuidV4IdempotencyKeyGenerator();

  final MockPaymentFunctionInvoker _invoker;
  final IdempotencyKeyGenerator _keyGenerator;

  Future<CompleteTaskResponse> complete({
    required String challengeTaskId,
    String? idempotencyKey,
  }) async {
    try {
      final key = idempotencyKey ?? _keyGenerator.generate();
      final response = await _invoker.invoke(
        'complete-task',
        body: {'challenge_task_id': challengeTaskId, 'idempotency_key': key},
      );
      if (response.statusCode != 200) {
        throw CompleteTaskApiException.fromResponse(
          statusCode: response.statusCode,
          body: response.data,
        );
      }
      return CompleteTaskResponse.fromJson(response.data);
    } on CompleteTaskApiException {
      rethrow;
    } on FormatException {
      throw const CompleteTaskApiException(
        statusCode: 0,
        code: 'internal_error',
        userMessage: 'タスク完了の応答を解釈できませんでした。',
      );
    } catch (_) {
      throw const CompleteTaskApiException(
        statusCode: 0,
        code: 'internal_error',
        userMessage: 'タスク完了サービスに接続できませんでした。',
      );
    }
  }
}
