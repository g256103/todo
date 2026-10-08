import 'package:supabase_flutter/supabase_flutter.dart';

/// Client-side estimate of server UTC time using a one-shot RPC offset.
///
/// Offline or RPC failure: offset stays at zero (device UTC; spec appendix A ⑰).
class ServerClock {
  ServerClock({this._client});

  final SupabaseClient? _client;

  Duration _offset = Duration.zero;
  DateTime? _lastSyncedAt;

  Duration get offset => _offset;

  DateTime? get lastSyncedAt => _lastSyncedAt;

  DateTime nowUtc() => DateTime.now().toUtc().add(_offset);

  Future<void> sync() async {
    final client = _client ?? Supabase.instance.client;
    if (client.auth.currentSession == null) {
      _offset = Duration.zero;
      _lastSyncedAt = null;
      return;
    }

    final started = DateTime.now().toUtc();
    try {
      final serverRaw = await client.rpc('get_server_time');
      if (serverRaw is! String) return;
      final serverTime = DateTime.parse(serverRaw).toUtc();
      final finished = DateTime.now().toUtc();
      final rtt = finished.difference(started);
      final estimate = serverTime.add(rtt ~/ 2);
      _offset = estimate.difference(finished);
      _lastSyncedAt = finished;
    } catch (_) {
      // Keep the previous offset when re-sync fails.
    }
  }

  void reset() {
    _offset = Duration.zero;
    _lastSyncedAt = null;
  }
}

final ServerClock serverClock = ServerClock();
