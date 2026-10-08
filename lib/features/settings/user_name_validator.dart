String? validateUserName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'ユーザー名を入力してください。';
  }
  if (trimmed.runes.length > 50) {
    return 'ユーザー名は50文字以内で入力してください。';
  }
  return null;
}
