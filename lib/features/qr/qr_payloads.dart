/// Preview and claim QR payload strings (spec ch.8.2 / 8.5).
String buildPreviewQrPayload(String challengeId) {
  final id = challengeId.toLowerCase();
  return 'https://paypay-commit.mock/preview?challenge_id=$id';
}

String buildClaimQrPayload({required String token, required int amount}) {
  return Uri(
    scheme: 'https',
    host: 'paypay-commit.mock',
    path: '/claim',
    queryParameters: {
      'token': token,
      'amount': amount.toString(),
      'status': 'VERIFIED',
    },
  ).toString();
}

/// Extracts claim token from scanned QR content; returns null for preview or invalid URLs.
String? extractClaimTokenFromQrContent(String raw) {
  final trimmed = raw.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (uri.scheme != 'https' || uri.host != 'paypay-commit.mock') return null;
  if (uri.path != '/claim') return null;
  final token = uri.queryParameters['token'];
  if (token == null || token.isEmpty) return null;
  return token;
}
