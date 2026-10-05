String? validateTaskName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'タスク名を入力してください。';
  }
  if (trimmed.runes.length > 100) {
    return 'タスク名は100文字以内で入力してください。';
  }
  return null;
}
