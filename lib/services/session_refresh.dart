import 'package:supabase_flutter/supabase_flutter.dart';

/// Proactive refresh before Edge calls (spec appendix A ⑯; SDK auto-refresh remains primary).
const Duration sessionRefreshLeadTime = Duration(minutes: 5);

Future<void> ensureFreshSession(SupabaseClient client) async {
  final session = client.auth.currentSession;
  if (session == null) return;

  final expiresAt = session.expiresAt;
  if (expiresAt == null) return;

  final expires = DateTime.fromMillisecondsSinceEpoch(
    expiresAt * 1000,
    isUtc: true,
  );
  final now = DateTime.now().toUtc();
  if (expires.difference(now) > sessionRefreshLeadTime) return;

  try {
    await client.auth.refreshSession();
  } catch (_) {
    // Invoke may still succeed; SDK may refresh on 401.
  }
}
