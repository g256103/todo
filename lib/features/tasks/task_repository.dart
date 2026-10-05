import 'package:supabase_flutter/supabase_flutter.dart';

class Task {
  const Task({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
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

class TaskRepository {
  TaskRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Task>> fetchTasks() async {
    final rows = await _client
        .from('tasks')
        .select('id,user_id,name,created_at,updated_at')
        .order('created_at', ascending: true);
    return rows.map((row) => Task.fromJson(row)).toList();
  }

  Future<void> addTask(String name) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('ログインユーザーを取得できませんでした。');
    }
    await _client.from('tasks').insert({'user_id': user.id, 'name': name});
  }

  Future<void> updateTaskName(String id, String name) async {
    await _client.from('tasks').update({'name': name}).eq('id', id);
  }

  Future<void> deleteTask(String id) async {
    await _client.from('tasks').delete().eq('id', id);
  }
}
