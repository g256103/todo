import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/tasks/task_name_validator.dart';

void main() {
  test('空文字は無効', () {
    expect(validateTaskName(''), isNotNull);
  });

  test('空白のみは無効', () {
    expect(validateTaskName(' \t\n '), isNotNull);
  });

  test('100文字は有効', () {
    expect(validateTaskName('a' * 100), isNull);
  });

  test('101文字は無効', () {
    expect(validateTaskName('a' * 101), isNotNull);
  });

  test('絵文字を含む100 runeの名前は有効', () {
    expect(validateTaskName('😀' * 100), isNull);
  });
}
