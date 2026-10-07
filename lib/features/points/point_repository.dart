import 'package:supabase_flutter/supabase_flutter.dart';

class PointTransactionItem {
  const PointTransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.expiresAt,
    this.remainingAmount,
  });

  factory PointTransactionItem.fromJson(Map<String, dynamic> json) {
    return PointTransactionItem(
      id: json['id'] as String,
      type: json['type'] as String,
      amount: json['amount'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      remainingAmount: json['remaining_amount'] as int?,
    );
  }

  final String id;
  final String type;
  final int amount;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int? remainingAmount;
}

class PointRepository {
  PointRepository({SupabaseClient? client}) : _providedClient = client;

  final SupabaseClient? _providedClient;
  SupabaseClient get _client => _providedClient ?? Supabase.instance.client;

  Future<int> fetchAvailablePoints() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;

    final response = await _client
        .from('points')
        .select('available_points')
        .eq('user_id', user.id)
        .maybeSingle();

    if (response == null) return 0;
    return (response['available_points'] as num?)?.toInt() ?? 0;
  }

  Future<List<PointTransactionItem>> fetchTransactions() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    final response = await _client
        .from('point_transactions')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((item) => PointTransactionItem.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
