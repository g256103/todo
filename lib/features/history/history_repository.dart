import 'package:supabase_flutter/supabase_flutter.dart';

class ChallengeHistoryTask {
  const ChallengeHistoryTask({
    required this.id,
    required this.taskNameSnapshot,
    required this.status,
    this.completedAt,
  });

  factory ChallengeHistoryTask.fromJson(Map<String, dynamic> json) {
    return ChallengeHistoryTask(
      id: json['id'] as String,
      taskNameSnapshot: json['task_name_snapshot'] as String,
      status: json['status'] as String,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
    );
  }

  final String id;
  final String taskNameSnapshot;
  final String status;
  final DateTime? completedAt;

  bool get isCompleted => status == 'COMPLETED';
}

class ChallengeHistoryItem {
  const ChallengeHistoryItem({
    required this.id,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.deadline,
    this.startedAt,
    this.finishedAt,
    this.tasks = const [],
  });

  factory ChallengeHistoryItem.fromJson(
    Map<String, dynamic> json,
    List<ChallengeHistoryTask> tasks,
  ) {
    return ChallengeHistoryItem(
      id: json['id'] as String,
      amount: json['amount'] as int,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      deadline: DateTime.parse(json['deadline'] as String),
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
      finishedAt: json['finished_at'] != null
          ? DateTime.tryParse(json['finished_at'] as String)
          : null,
      tasks: tasks,
    );
  }

  final String id;
  final int amount;
  final String status;
  final DateTime createdAt;
  final DateTime deadline;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final List<ChallengeHistoryTask> tasks;

  bool get isSuccess => status == 'SUCCESS';
  bool get isFailed => status == 'FAILED';
}

class HistoryRepository {
  HistoryRepository({SupabaseClient? client}) : _providedClient = client;

  final SupabaseClient? _providedClient;
  SupabaseClient get _client => _providedClient ?? Supabase.instance.client;

  Future<List<ChallengeHistoryItem>> fetchHistory() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    final challengesResponse = await _client
        .from('challenges')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final challengeRows = (challengesResponse as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);

    if (challengeRows.isEmpty) return const [];

    final challengeIds =
        challengeRows.map((c) => c['id'] as String).toList(growable: false);

    final tasksResponse = await _client
        .from('challenge_tasks')
        .select()
        .inFilter('challenge_id', challengeIds)
        .order('sort_order', ascending: true);

    final taskMap = <String, List<ChallengeHistoryTask>>{};
    for (final raw in tasksResponse as List<dynamic>) {
      final json = Map<String, dynamic>.from(raw as Map);
      final challengeId = json['challenge_id'] as String;
      taskMap
          .putIfAbsent(challengeId, () => [])
          .add(ChallengeHistoryTask.fromJson(json));
    }

    return challengeRows.map((c) {
      final id = c['id'] as String;
      return ChallengeHistoryItem.fromJson(c, taskMap[id] ?? const []);
    }).toList(growable: false);
  }
}
