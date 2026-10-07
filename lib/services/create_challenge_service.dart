import 'mock_payment_service.dart';

class ChallengeTask {
  const ChallengeTask({
    required this.id,
    required this.taskId,
    required this.taskNameSnapshot,
    required this.sortOrder,
    required this.status,
  });

  factory ChallengeTask.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final taskId = json['task_id'];
    final name = json['task_name_snapshot'];
    final sortOrder = json['sort_order'];
    final status = json['status'];
    if (id is! String ||
        taskId is! String ||
        name is! String ||
        sortOrder is! int ||
        status is! String) {
      throw const FormatException('Invalid challenge task response.');
    }
    return ChallengeTask(
      id: id,
      taskId: taskId,
      taskNameSnapshot: name,
      sortOrder: sortOrder,
      status: status,
    );
  }

  final String id;
  final String taskId;
  final String taskNameSnapshot;
  final int sortOrder;
  final String status;
}

class CreateChallenge {
  const CreateChallenge({
    required this.id,
    required this.paymentId,
    required this.amount,
    required this.status,
    required this.autoStartAt,
    required this.deadline,
    required this.challengeTasks,
  });

  factory CreateChallenge.fromResponse(Object? data) {
    try {
      if (data is! Map) throw const FormatException();
      final challenge = data['challenge'];
      final rawTasks = data['challenge_tasks'];
      if (challenge is! Map || rawTasks is! List) {
        throw const FormatException();
      }
      final json = Map<String, dynamic>.from(challenge);
      final id = json['id'];
      final paymentId = json['payment_id'];
      final amount = json['amount'];
      final status = json['status'];
      final autoStartAt = json['auto_start_at'];
      final deadline = json['deadline'];
      if (id is! String ||
          paymentId is! String ||
          amount is! int ||
          status is! String ||
          autoStartAt is! String ||
          deadline is! String) {
        throw const FormatException();
      }
      return CreateChallenge(
        id: id,
        paymentId: paymentId,
        amount: amount,
        status: status,
        autoStartAt: DateTime.parse(autoStartAt),
        deadline: DateTime.parse(deadline),
        challengeTasks: rawTasks
            .map(
              (task) => ChallengeTask.fromJson(
                Map<String, dynamic>.from(task as Map),
              ),
            )
            .toList(),
      );
    } on FormatException {
      throw const FormatException('Invalid challenge response.');
    } on TypeError {
      throw const FormatException('Invalid challenge response.');
    }
  }

  final String id;
  final String paymentId;
  final int amount;
  final String status;
  final DateTime autoStartAt;
  final DateTime deadline;
  final List<ChallengeTask> challengeTasks;
}

class CreateChallengeApiException implements Exception {
  const CreateChallengeApiException({
    required this.statusCode,
    required this.code,
    required this.userMessage,
  });

  factory CreateChallengeApiException.fromResponse({
    required int statusCode,
    required Object? body,
  }) {
    final code = body is Map && body['error_code'] is String
        ? body['error_code'] as String
        : 'internal_error';
    return CreateChallengeApiException(
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
      'CreateChallengeApiException(statusCode: $statusCode, code: $code)';
}

String _messageFor(String code) {
  switch (code) {
    case 'unauthorized':
      return 'ログインが必要です。';
    case 'payment_not_found':
    case 'task_not_found':
    case 'routine_not_found':
      return '選択したデータが見つかりません。画面を更新してお試しください。';
    case 'payment_not_successful':
    case 'payment_not_success':
      return '支払いが確定していないため、Challengeを作成できません。';
    case 'active_challenge_exists':
      return '進行中のChallengeがあります。完了後にお試しください。';
    case 'idempotency_key_reused':
      return 'Challenge作成が重複しています。もう一度お試しください。';
    case 'no_tasks_selected':
      return 'TaskまたはRoutineを1つ以上選択してください。';
    case 'invalid_uuid':
    case 'unknown_field':
    case 'invalid_idempotency_key':
      return 'Challengeの入力情報が正しくありません。';
    case 'challenge_creation_conflict':
      return 'Challenge作成が競合しました。もう一度お試しください。';
    case 'temporary_unavailable':
      return 'Challengeサービスが一時的に利用できません。';
    default:
      return 'Challengeの作成に失敗しました。';
  }
}

class CreateChallengeService {
  CreateChallengeService({
    MockPaymentFunctionInvoker? invoker,
    IdempotencyKeyGenerator? keyGenerator,
  }) : _invoker = invoker ?? SupabaseMockPaymentFunctionInvoker(),
       _keyGenerator = keyGenerator ?? UuidV4IdempotencyKeyGenerator();

  final MockPaymentFunctionInvoker _invoker;
  final IdempotencyKeyGenerator _keyGenerator;

  Future<CreateChallenge> create({
    required String paymentId,
    required List<String> taskIds,
    required List<String> routineIds,
  }) async {
    try {
      final response = await _invoker.invoke(
        'create-challenge',
        body: {
          'payment_id': paymentId,
          'task_ids': List<String>.from(taskIds),
          'routine_ids': List<String>.from(routineIds),
          'idempotency_key': _keyGenerator.generate(),
        },
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw CreateChallengeApiException.fromResponse(
          statusCode: response.statusCode,
          body: response.data,
        );
      }
      return CreateChallenge.fromResponse(response.data);
    } on CreateChallengeApiException {
      rethrow;
    } on FormatException {
      throw const CreateChallengeApiException(
        statusCode: 0,
        code: 'internal_error',
        userMessage: 'Challengeサービスの応答を解釈できませんでした。',
      );
    } on TypeError {
      throw const CreateChallengeApiException(
        statusCode: 0,
        code: 'internal_error',
        userMessage: 'Challengeサービスの応答を解釈できませんでした。',
      );
    } catch (_) {
      throw const CreateChallengeApiException(
        statusCode: 0,
        code: 'internal_error',
        userMessage: 'Challengeサービスに接続できませんでした。',
      );
    }
  }
}
