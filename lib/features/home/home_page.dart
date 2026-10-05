import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_service.dart';
import '../tasks/task_name_validator.dart';
import '../tasks/task_repository.dart';

class TabbedHomePage extends StatefulWidget {
  const TabbedHomePage({
    super.key,
    required this.authService,
    required this.session,
  });

  final AuthService authService;
  final Session session;

  @override
  State<TabbedHomePage> createState() => _TabbedHomePageState();
}

class _TabbedHomePageState extends State<TabbedHomePage> {
  static const _titles = ['メイン', 'ポイント', '設定', '履歴', '編集'];
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const _PlaceholderPage(message: '準備中'),
      const _PlaceholderPage(message: '準備中'),
      _SettingsPage(authService: widget.authService, session: widget.session),
      const _PlaceholderPage(message: '準備中'),
      const TaskEditorPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedIndex])),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'メイン',
          ),
          NavigationDestination(
            icon: Icon(Icons.stars_outlined),
            selectedIcon: Icon(Icons.stars),
            label: 'ポイント',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: '履歴'),
          NavigationDestination(
            icon: Icon(Icons.edit_outlined),
            selectedIcon: Icon(Icons.edit),
            label: '編集',
          ),
        ],
      ),
    );
  }
}

class TaskEditorPage extends StatefulWidget {
  const TaskEditorPage({super.key, this._repository});

  final TaskRepository? _repository;

  @override
  State<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<TaskEditorPage> {
  late final TaskRepository _repository;
  List<Task> _tasks = [];
  bool _isLoading = true;
  bool _isRequestInProgress = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget._repository ?? TaskRepository();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final tasks = await _repository.fetchTasks();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
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

  Future<void> _addTask() async {
    final name = await _showTaskNameDialog(title: 'タスクを追加');
    if (name == null || !mounted) return;
    await _runRequest(() => _repository.addTask(name));
  }

  Future<void> _editTask(Task task) async {
    final name = await _showTaskNameDialog(
      title: 'タスク名を編集',
      initialValue: task.name,
    );
    if (name == null || !mounted) return;
    await _runRequest(() => _repository.updateTaskName(task.id, name));
  }

  Future<void> _deleteTask(Task task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('タスクを削除しますか？'),
        content: Text(
          '「${task.name}」を削除します。\n'
          'ルーティーンからも外れます。',
        ),
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
    await _runRequest(() => _repository.deleteTask(task.id));
  }

  Future<void> _runRequest(Future<void> Function() request) async {
    setState(() {
      _isRequestInProgress = true;
      _errorMessage = null;
    });
    try {
      await request();
      await _loadTasks();
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

  Future<String?> _showTaskNameDialog({
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
              labelText: 'タスク名',
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
                          validationError = error;
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _isRequestInProgress ? _skipRefresh : _loadTasks,
          child: _buildContent(),
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

  Future<void> _skipRefresh() async {}

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _ErrorContent(message: _errorMessage!, onRetry: _loadTasks);
    }
    if (_tasks.isEmpty) {
      return _EmptyTasksContent(onAdd: _isRequestInProgress ? null : _addTask);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _tasks.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == _tasks.length) {
          return OutlinedButton.icon(
            onPressed: _isRequestInProgress ? null : _addTask,
            icon: const Icon(Icons.add),
            label: const Text('タスクを追加'),
          );
        }
        final task = _tasks[index];
        return Card(
          child: ListTile(
            title: Text(task.name),
            trailing: Wrap(
              children: [
                IconButton(
                  onPressed: _isRequestInProgress
                      ? null
                      : () => _editTask(task),
                  tooltip: '編集',
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: _isRequestInProgress
                      ? null
                      : () => _deleteTask(task),
                  tooltip: '削除',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyTasksContent extends StatelessWidget {
  const _EmptyTasksContent({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('タスクがありません。'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('タスクを追加'),
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

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message));
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.authService, required this.session});

  final AuthService authService;
  final Session session;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  bool _isSigningOut = false;
  String? _errorMessage;

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
      _errorMessage = null;
    });
    try {
      await widget.authService.signOut();
    } on AuthException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.session.user.email != null)
              Text(widget.session.user.email!),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSigningOut ? null : _signOut,
              icon: const Icon(Icons.logout),
              label: Text(_isSigningOut ? 'ログアウト中...' : 'ログアウト'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
