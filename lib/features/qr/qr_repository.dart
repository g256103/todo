import 'package:supabase_flutter/supabase_flutter.dart';

class QrCodeRecord {
  const QrCodeRecord({
    required this.id,
    required this.challengeId,
    required this.token,
    required this.status,
    this.usedAt,
  });

  factory QrCodeRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final challengeId = json['challenge_id'];
    final token = json['token'];
    final status = json['status'];
    if (id is! String ||
        challengeId is! String ||
        token is! String ||
        status is! String) {
      throw const FormatException('Invalid qr_codes row.');
    }
    return QrCodeRecord(
      id: id,
      challengeId: challengeId,
      token: token,
      status: status,
      usedAt: json['used_at'] is String
          ? DateTime.tryParse(json['used_at'] as String)
          : null,
    );
  }

  final String id;
  final String challengeId;
  final String token;
  final String status;
  final DateTime? usedAt;

  bool get isAvailable => status == 'AVAILABLE';
  bool get isUsed => status == 'USED';
}

class QrRepository {
  QrRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<QrCodeRecord?> fetchByChallengeId(String challengeId) async {
    final data = await _client
        .from('qr_codes')
        .select('id, challenge_id, token, status, used_at')
        .eq('challenge_id', challengeId)
        .maybeSingle();
    if (data == null) return null;
    return QrCodeRecord.fromJson(Map<String, dynamic>.from(data));
  }
}
