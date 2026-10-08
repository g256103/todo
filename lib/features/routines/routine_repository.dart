import 'package:supabase_flutter/supabase_flutter.dart';

import '../tasks/task_repository.dart';

class Routine {
  const Routine({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String userId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class RoutineTask {
  const RoutineTask({
    required this.routineId,
    required this.taskId,
    required this.userId,
    required this.sortOrder,
  });

  factory RoutineTask.fromJson(Map<String, dynamic> json) {
    return RoutineTask(
      routineId: json['routine_id'] as String,
      taskId: json['task_id'] as String,
      userId: json['user_id'] as String,
      sortOrder: json['sort_order'] as int,
    );
  }

  final String routineId;
  final String taskId;
  final String userId;
  final int sortOrder;
}

int nextRoutineTaskSortOrder(Iterable<int> sortOrders) {
  if (sortOrders.isEmpty) return 0;
  return sortOrders.reduce((a, b) => a > b ? a : b) + 1;
}

Set<String> checkedTaskIdsForRoutine(
  Iterable<RoutineTask> routineTasks,
  Iterable<Task> tasks,
  String routineId,
) {
  final taskIds = tasks.map((task) => task.id).toSet();
  return routineTasks
      .where(
        (routineTask) =>
            routineTask.routineId == routineId &&
            taskIds.contains(routineTask.taskId),
      )
      .map((routineTask) => routineTask.taskId)
      .toSet();
}

class RoutineRepository {
  RoutineRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Routine>> fetchRoutines() async {
    final rows = await _client
        .from('routines')
        .select('id,user_id,name,created_at,updated_at')
        .order('created_at', ascending: true);
    return rows.map((row) => Routine.fromJson(row)).toList();
  }

  Future<List<RoutineTask>> fetchRoutineTasks(String routineId) async {
    final rows = await _client
        .from('routine_tasks')
        .select('routine_id,task_id,user_id,sort_order')
        .eq('routine_id', routineId)
        .order('sort_order', ascending: true);
    return rows.map((row) => RoutineTask.fromJson(row)).toList();
  }

  Future<void> addRoutine(String name) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('ログインユーザーを取得できませんでした。');
    }
    await _client.from('routines').insert({'user_id': user.id, 'name': name});
  }

  Future<void> updateRoutineName(String id, String name) async {
    await _client.from('routines').update({'name': name}).eq('id', id);
  }

  Future<void> deleteRoutine(String id) async {
    await _client.from('routines').delete().eq('id', id);
  }

  Future<void> addTaskToRoutine(String routineId, String taskId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('ログインユーザーを取得できませんでした。');
    }
    final existing = await fetchRoutineTasks(routineId);
    final sortOrder = nextRoutineTaskSortOrder(
      existing.map((routineTask) => routineTask.sortOrder),
    );
    await _client.from('routine_tasks').insert({
      'routine_id': routineId,
      'task_id': taskId,
      'user_id': user.id,
      'sort_order': sortOrder,
    });
  }

  Future<void> removeTaskFromRoutine(String routineId, String taskId) async {
    await _client
        .from('routine_tasks')
        .delete()
        .eq('routine_id', routineId)
        .eq('task_id', taskId);
  }
}
