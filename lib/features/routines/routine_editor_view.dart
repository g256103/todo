import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../tasks/task_name_validator.dart';
import '../tasks/task_repository.dart';
import 'routine_repository.dart';

class RoutineEditorView extends StatefulWidget {
  const RoutineEditorView({
    super.key,
    this._taskRepository,
    this._routineRepository,
  });

  final TaskRepository? _taskRepository;
  final RoutineRepository? _routineRepository;

  @override
  State<RoutineEditorView> createState() => _RoutineEditorViewState();
}

class _RoutineEditorViewState extends State<RoutineEditorView> {
  late final TaskRepository _taskRepository;
  late final RoutineRepository _routineRepository;
  List<Routine> _routines = [];
  bool _isLoading = true;
  bool _isRequestInProgress = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _taskRepository = widget._taskRepository ?? TaskRepository();
    _routineRepository = widget._routineRepository ?? RoutineRepository();
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final routines = await _routineRepository.fetchRoutines();
      if (!mounted) return;
      setState(() {
        _routines = routines;
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError(error.toString());
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  Future<void> _addRoutine() async {
    final name = await _showRoutineNameDialog(title: 'ルーティーンを追加');
    if (name == null || !mounted) return;
    await _runRequest(() => _routineRepository.addRoutine(name));
  }

  Future<void> _editRoutine(Routine routine) async {
    final name = await _showRoutineNameDialog(
      title: 'ルーティーン名を編集',
      initialValue: routine.name,
    );
    if (name == null || !mounted) return;
    await _runRequest(
      () => _routineRepository.updateRoutineName(routine.id, name),
    );
  }

  Future<void> _deleteRoutine(Routine routine) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ルーティーンを削除しますか？'),
        content: Text('「${routine.name}」を削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: _isRequestInProgress
                ? null
                : () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    await _runRequest(() => _routineRepository.deleteRoutine(routine.id));
  }

  Future<void> _runRequest(Future<void> Function() request) async {
    setState(() {
      _isRequestInProgress = true;
      _errorMessage = null;
    });
    try {
      await request();
      await _loadRoutines();
    } on PostgrestException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isRequestInProgress = false;
        });
      }
    }
  }

  Future<String?> _showRoutineNameDialog({
    required String title,
    String? initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    String? validationError;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: 'ルーティーン名',
              errorText: validationError,
            ),
            onChanged: (_) {
              if (validationError != null) {
                setDialogState(() {
                  validationError = null;
                });
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: _isRequestInProgress
                  ? null
                  : () {
                      final error = validateTaskName(controller.text);
                      if (error != null) {
                        setDialogState(() {
                          validationError = error.replaceAll('タスク名', 'ルーティーン名');
                        });
                        return;
                      }
                      Navigator.of(context).pop(controller.text.trim());
                    },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _showRoutineTasks(Routine routine) async {
    try {
      final tasks = await _taskRepository.fetchTasks();
      final routineTasks = await _routineRepository.fetchRoutineTasks(
        routine.id,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(routine.name),
          content: _RoutineTaskNames(
            routineTasks: routineTasks,
            tasks: tasks,
            emptyMessage: 'タスクがありません',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    } on PostgrestException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError(error.toString());
    }
  }

  Future<void> _editRoutineTasks(Routine routine) async {
    try {
      final tasks = await _taskRepository.fetchTasks();
      var routineTasks = await _routineRepository.fetchRoutineTasks(routine.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _RoutineTaskChecklistDialog(
          routine: routine,
          tasks: tasks,
          initialRoutineTasks: routineTasks,
          repository: _routineRepository,
          onChanged: (updated) {
            routineTasks = updated;
          },
        ),
      );
    } on PostgrestException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _ErrorContent(message: _errorMessage!, onRetry: _loadRoutines);
    }
    if (_routines.isEmpty) {
      return _EmptyRoutinesContent(
        onAdd: _isRequestInProgress ? null : _addRoutine,
      );
    }
    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: _routines.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == _routines.length) {
              return OutlinedButton.icon(
                onPressed: _isRequestInProgress ? null : _addRoutine,
                icon: const Icon(Icons.add),
                label: const Text('ルーティーンを追加'),
              );
            }
            final routine = _routines[index];
            return Card(
              child: ListTile(
                onLongPress: _isRequestInProgress
                    ? null
                    : () => _showRoutineTasks(routine),
                title: Text(routine.name),
                subtitle: const Text('長押しで含まれるタスクを確認'),
                trailing: Wrap(
                  children: [
                    IconButton(
                      onPressed: _isRequestInProgress
                          ? null
                          : () => _editRoutineTasks(routine),
                      tooltip: 'タスクを編集',
                      icon: const Icon(Icons.checklist),
                    ),
                    IconButton(
                      onPressed: _isRequestInProgress
                          ? null
                          : () => _editRoutine(routine),
                      tooltip: '編集',
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: _isRequestInProgress
                          ? null
                          : () => _deleteRoutine(routine),
                      tooltip: '削除',
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (_isRequestInProgress)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _RoutineTaskChecklistDialog extends StatefulWidget {
  const _RoutineTaskChecklistDialog({
    required this.routine,
    required this.tasks,
    required this.initialRoutineTasks,
    required this.repository,
    required this.onChanged,
  });

  final Routine routine;
  final List<Task> tasks;
  final List<RoutineTask> initialRoutineTasks;
  final RoutineRepository repository;
  final ValueChanged<List<RoutineTask>> onChanged;

  @override
  State<_RoutineTaskChecklistDialog> createState() =>
      _RoutineTaskChecklistDialogState();
}

class _RoutineTaskChecklistDialogState
    extends State<_RoutineTaskChecklistDialog> {
  late final Set<String> _selectedTaskIds = widget.initialRoutineTasks
      .map((routineTask) => routineTask.taskId)
      .toSet();
  String? _errorMessage;
  bool _isSaving = false;

  void _toggleTask(Task task, bool? selected) {
    if (selected == true) {
      _selectedTaskIds.add(task.id);
    } else {
      _selectedTaskIds.remove(task.id);
    }
    setState(() {
      _errorMessage = null;
    });
  }

  Future<void> _confirm() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    final initialTaskIds = widget.initialRoutineTasks
        .map((routineTask) => routineTask.taskId)
        .toSet();
    final removedTaskIds = initialTaskIds.difference(_selectedTaskIds);
    final addedTaskIds = _selectedTaskIds.difference(initialTaskIds);
    try {
      for (final taskId in removedTaskIds) {
        await widget.repository.removeTaskFromRoutine(
          widget.routine.id,
          taskId,
        );
      }
      for (final taskId in addedTaskIds) {
        try {
          await widget.repository.addTaskToRoutine(widget.routine.id, taskId);
        } on PostgrestException catch (error) {
          if (error.code != '23505') rethrow;
        }
      }
      final updated = await widget.repository.fetchRoutineTasks(
        widget.routine.id,
      );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      widget.onChanged(updated);
      Navigator.of(context).pop();
    } on PostgrestException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError(error.toString());
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('ルーティーンに追加するタスク'),
          ),
          const SizedBox(height: 8),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_errorMessage!),
            ),
          if (widget.tasks.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('先にタスクを追加してください'),
            )
          else
            Flexible(
              child: Material(
                color:
                    Theme.of(context).dialogTheme.backgroundColor ??
                    Theme.of(context).colorScheme.surface,
                child: ListView(
                  shrinkWrap: true,
                  children: widget.tasks.map((task) {
                    return CheckboxListTile(
                      value: _selectedTaskIds.contains(task.id),
                      onChanged: _isSaving
                          ? null
                          : (selected) => _toggleTask(task, selected),
                      title: Text(task.name),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                child: const Text('キャンセル'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSaving ? null : _confirm,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('確定'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoutineTaskNames extends StatelessWidget {
  const _RoutineTaskNames({
    required this.routineTasks,
    required this.tasks,
    required this.emptyMessage,
  });

  final List<RoutineTask> routineTasks;
  final List<Task> tasks;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final taskNames = <String>[];
    for (final routineTask in routineTasks) {
      for (final task in tasks) {
        if (task.id == routineTask.taskId) {
          taskNames.add(task.name);
          break;
        }
      }
    }
    if (taskNames.isEmpty) return Text(emptyMessage);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: taskNames
              .map(
                (name) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('・$name'),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _EmptyRoutinesContent extends StatelessWidget {
  const _EmptyRoutinesContent({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ルーティーンがありません。'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('ルーティーンを追加'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
          ],
        ),
      ),
    );
  }
}
