import 'package:supabase_flutter/supabase_flutter.dart';

class CashoutProgress {
  const CashoutProgress({required this.successCount, this.firstSuccessAt});

  final int successCount;
  final DateTime? firstSuccessAt;

  bool isEligible(DateTime now) {
    if (successCount < 7 || firstSuccessAt == null) return false;
    return !now.isBefore(firstSuccessAt!.add(const Duration(days: 7)));
  }

  int daysUntilContinuityMet(DateTime now) {
    if (firstSuccessAt == null) return 7;
    final target = firstSuccessAt!.add(const Duration(days: 7));
    if (!now.isBefore(target)) return 0;
    final hours = target.difference(now).inHours;
    return (hours <= 0) ? 0 : ((hours + 23) / 24).ceil();
  }

  String? cashoutBlockReason(DateTime now) {
    if (successCount < 7) {
      return 'チャレンジ成功が7回に達していません（現在 $successCount / 7）。';
    }
    final daysLeft = daysUntilContinuityMet(now);
    if (daysLeft > 0) {
      return '初回成功から1週間経過していません（あと $daysLeft 日）。';
    }
    return null;
  }
}

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

  Future<CashoutProgress> fetchCashoutProgress() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const CashoutProgress(successCount: 0);
    }

    final response = await _client
        .from('challenges')
        .select('finished_at')
        .eq('user_id', user.id)
        .eq('status', 'SUCCESS');

    final rows = response as List<dynamic>;
    if (rows.isEmpty) {
      return const CashoutProgress(successCount: 0);
    }

    DateTime? firstSuccess;
    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      final raw = map['finished_at'];
      if (raw is! String) continue;
      final finished = DateTime.parse(raw).toUtc();
      if (firstSuccess == null || finished.isBefore(firstSuccess)) {
        firstSuccess = finished;
      }
    }

    return CashoutProgress(
      successCount: rows.length,
      firstSuccessAt: firstSuccess,
    );
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
        .map(
          (item) => PointTransactionItem.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }
}
