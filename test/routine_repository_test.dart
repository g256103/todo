import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/routines/routine_repository.dart';
import 'package:todo/features/tasks/task_repository.dart';

void main() {
  group('nextRoutineTaskSortOrder', () {
    test('空なら0', () {
      expect(nextRoutineTaskSortOrder([]), 0);
    });

    test('連番なら最大値の次', () {
      expect(nextRoutineTaskSortOrder([0, 1, 2]), 3);
    });

    test('欠番があっても最大値の次', () {
      expect(nextRoutineTaskSortOrder([0, 2, 5]), 6);
    });
  });

  test('routine_tasksとタスク一覧からチェック状態を組み立てる', () {
    final tasks = [
      Task(
        id: 'task-1',
        userId: 'user-1',
        name: 'Task 1',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      Task(
        id: 'task-2',
        userId: 'user-1',
        name: 'Task 2',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ];
    const routineTasks = [
      RoutineTask(
        routineId: 'routine-1',
        taskId: 'task-2',
        userId: 'user-1',
        sortOrder: 0,
      ),
      RoutineTask(
        routineId: 'routine-2',
        taskId: 'task-1',
        userId: 'user-1',
        sortOrder: 0,
      ),
    ];

    expect(checkedTaskIdsForRoutine(routineTasks, tasks, 'routine-1'), {
      'task-2',
    });
  });
}
