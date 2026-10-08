import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_service.dart';
import '../history/history_repository.dart';
import '../points/point_catalog.dart';
import '../points/point_repository.dart';
import '../settings/settings_tab.dart';
import '../../services/cashout_points_service.dart';
import '../../services/purchase_points_service.dart';
import 'mock_payment_home_page.dart';
import '../routines/routine_editor_view.dart';
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
      const MockPaymentHomePage(),
      const PointsPage(),
      SettingsTab(authService: widget.authService, session: widget.session),
      const HistoryPage(),
      const TaskEditorPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedIndex])),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: NavigationBar(
            backgroundColor: Colors.white.withValues(alpha: 0.82),
            elevation: 0,
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
        ),
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
  bool _showRoutines = false;
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
    if (_showRoutines) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('タスク')),
                ButtonSegment(value: true, label: Text('ルーティーン')),
              ],
              selected: {_showRoutines},
              onSelectionChanged: (selection) {
                setState(() {
                  _showRoutines = selection.first;
                });
              },
            ),
          ),
          const Expanded(child: RoutineEditorView()),
        ],
      );
    }
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('タスク')),
                  ButtonSegment(value: true, label: Text('ルーティーン')),
                ],
                selected: {_showRoutines},
                onSelectionChanged: (selection) {
                  setState(() {
                    _showRoutines = selection.first;
                  });
                },
              ),
            ),
            Expanded(child: _buildTaskContent()),
          ],
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

  Widget _buildTaskContent() {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _isRequestInProgress ? _skipRefresh : _loadTasks,
          child: _buildContent(),
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

class PointsPage extends StatefulWidget {
  const PointsPage({
    super.key,
    this.repository,
    this.purchaseService,
    this.cashoutService,
  });

  final PointRepository? repository;
  final PurchasePointsService? purchaseService;
  final CashoutPointsService? cashoutService;

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  late final PointRepository _repository;
  late final PurchasePointsService _purchaseService;
  late final CashoutPointsService _cashoutService;
  int _points = 0;
  CashoutProgress _cashoutProgress = const CashoutProgress(successCount: 0);
  List<PointTransactionItem> _transactions = [];
  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _actionMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PointRepository();
    _purchaseService = widget.purchaseService ?? PurchasePointsService();
    _cashoutService = widget.cashoutService ?? CashoutPointsService();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    try {
      final points = await _repository.fetchAvailablePoints();
      final progress = await _repository.fetchCashoutProgress();
      final txs = await _repository.fetchTransactions();
      if (!mounted) return;
      setState(() {
        _points = points;
        _cashoutProgress = progress;
        _transactions = txs;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _purchaseItem(PointCatalogItem item) async {
    if (_isActionInProgress) return;
    setState(() {
      _isActionInProgress = true;
      _actionMessage = null;
    });
    try {
      final result = await _purchaseService.purchase(catalogItemId: item.id);
      if (!mounted) return;
      setState(() => _points = result.availablePoints);
      await _loadPoints();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${result.itemName} と交換しました。')));
    } on PurchasePointsApiException catch (error) {
      if (!mounted) return;
      setState(() => _actionMessage = error.userMessage);
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _cashout() async {
    if (_isActionInProgress) return;
    final now = DateTime.now().toUtc();
    if (!_cashoutProgress.isEligible(now)) return;

    final pointsController = TextEditingController(text: '1000');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ポイント現金化（モック）'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('出金ポイント（1000pt以上・10pt単位、手数料10%）'),
              TextField(
                controller: pointsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'ポイント'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('申請'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final parsed = int.tryParse(pointsController.text.trim());
    if (parsed == null) {
      setState(() => _actionMessage = '出金ポイントを入力してください。');
      return;
    }

    setState(() {
      _isActionInProgress = true;
      _actionMessage = null;
    });
    try {
      final result = await _cashoutService.cashout(pointsUsed: parsed);
      if (!mounted) return;
      setState(() => _points = result.availablePoints);
      await _loadPoints();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'モック出金: ¥${result.cashAmount}（手数料 ${result.feePoints}pt）',
          ),
        ),
      );
    } on CashoutPointsApiException catch (error) {
      if (!mounted) return;
      setState(() => _actionMessage = error.userMessage);
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  String _transactionLabel(PointTransactionItem tx) {
    switch (tx.type) {
      case 'GRANT':
        return 'チャレンジ失敗による付与';
      case 'PURCHASE':
        return '教材交換';
      case 'CASHOUT':
        return '現金化';
      case 'EXPIRE':
        return '有効期限切れ';
      default:
        return tx.type;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now().toUtc();
    final successCount = _cashoutProgress.successCount;
    final daysLeft = _cashoutProgress.daysUntilContinuityMet(now);
    final cashoutEligible = _cashoutProgress.isEligible(now);
    final blockReason = _cashoutProgress.cashoutBlockReason(now);

    return RefreshIndicator(
      onRefresh: _loadPoints,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          const Text(
            'ポイント',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    '$_points pt',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '教育用途ポイント（有効期限3か月・譲渡不可）',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '現金化条件と進捗',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '7回成功かつ1週間以上の継続で現金化申請が可能です（手数料10%）。',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (successCount / 7).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(Colors.green),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$successCount / 7 回達成',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        daysLeft > 0 ? 'あと$daysLeft日' : '継続条件を満たしました',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  if (blockReason != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      blockReason,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ポイント利用・交換',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (final item in kPointPurchaseCatalog) ...[
                  ListTile(
                    leading: const Icon(Icons.menu_book, color: Colors.indigo),
                    title: Text(item.name),
                    subtitle: Text('${item.points} pt'),
                    trailing: _isActionInProgress
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: _points >= item.points
                                ? () => _purchaseItem(item)
                                : null,
                            child: const Text('交換'),
                          ),
                  ),
                  if (item != kPointPurchaseCatalog.last)
                    const Divider(height: 1),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.account_balance,
                    color: Colors.teal,
                  ),
                  title: const Text('口座へ出金（現金化・モック）'),
                  subtitle: Text(
                    cashoutEligible ? '条件を満たしています。' : '達成条件を満たすと申請できます。',
                  ),
                  trailing: FilledButton(
                    onPressed: cashoutEligible && !_isActionInProgress
                        ? _cashout
                        : null,
                    child: const Text('申請'),
                  ),
                ),
              ],
            ),
          ),
          if (_actionMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _actionMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_transactions.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('ポイント履歴', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final tx in _transactions)
              Card(
                elevation: 0,
                child: ListTile(
                  title: Text(_transactionLabel(tx)),
                  subtitle: Text(
                    tx.expiresAt != null
                        ? '有効期限: ${tx.expiresAt!.year}/${tx.expiresAt!.month}/${tx.expiresAt!.day}'
                        : '',
                  ),
                  trailing: Text(
                    '${tx.amount > 0 ? '+' : ''}${tx.amount} pt',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: tx.amount >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.repository});

  final HistoryRepository? repository;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final HistoryRepository _repository;
  List<ChallengeHistoryItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? HistoryRepository();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final items = await _repository.fetchHistory();
      if (!mounted) return;
      setState(() {
        _history = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: _history.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                const Text(
                  '履歴',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        const Text('まだチャレンジ履歴がありません。'),
                        const SizedBox(height: 4),
                        Text(
                          'コミット完了後にチャレンジ履歴が表示されます。',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _history.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      '履歴',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }
                final item = _history[index - 1];
                return _ChallengeHistoryCard(
                  item: item,
                  onShowDetail: () =>
                      _showChallengeHistoryDetail(context, item),
                );
              },
            ),
    );
  }

  Future<void> _showChallengeHistoryDetail(
    BuildContext context,
    ChallengeHistoryItem item,
  ) async {
    final dateStr =
        '${item.createdAt.year}/${item.createdAt.month.toString().padLeft(2, '0')}/${item.createdAt.day.toString().padLeft(2, '0')}';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$dateStr · ¥${item.amount}'),
        content: SingleChildScrollView(
          child: _ChallengeHistoryTaskSnapshotList(tasks: item.tasks),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

class _ChallengeHistoryTaskSnapshotList extends StatelessWidget {
  const _ChallengeHistoryTaskSnapshotList({required this.tasks});

  final List<ChallengeHistoryTask> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Text('タスクのスナップショットがありません。');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final task in tasks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  task.isCompleted ? Icons.check_circle : Icons.cancel,
                  size: 18,
                  color: task.isCompleted ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.taskNameSnapshot,
                    style: TextStyle(
                      color: task.isCompleted
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ChallengeHistoryCard extends StatelessWidget {
  const _ChallengeHistoryCard({required this.item, required this.onShowDetail});

  final ChallengeHistoryItem item;
  final VoidCallback onShowDetail;

  Color _statusColor() {
    switch (item.status) {
      case 'SUCCESS':
        return Colors.green;
      case 'FAILED':
        return Colors.red;
      case 'IN_PROGRESS':
        return Colors.blue;
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${item.createdAt.year}/${item.createdAt.month.toString().padLeft(2, '0')}/${item.createdAt.day.toString().padLeft(2, '0')}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onLongPress: onShowDetail,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.status,
                      style: TextStyle(
                        color: _statusColor(),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '¥${item.amount} コミット',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '長押しでタスク詳細',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
