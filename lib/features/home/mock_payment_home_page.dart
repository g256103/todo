import 'package:flutter/material.dart';

import '../../services/complete_task_service.dart';
import '../../services/create_challenge_service.dart';
import '../../services/mock_payment_service.dart';
import '../../services/start_challenge_service.dart';
import '../routines/routine_repository.dart';
import '../tasks/battery_hold_to_complete_tile.dart';
import '../tasks/task_repository.dart';

class MockPaymentHomePage extends StatefulWidget {
  const MockPaymentHomePage({
    super.key,
    this.paymentService,
    this.challengeService,
    this.startChallengeService,
    this.completeTaskService,
    this.taskRepository,
    this.taskLoader,
    this.routineRepository,
    this.routineLoader,
  });

  final MockPaymentService? paymentService;
  final CreateChallengeService? challengeService;
  final StartChallengeService? startChallengeService;
  final CompleteTaskService? completeTaskService;
  final TaskRepository? taskRepository;
  final Future<List<Task>> Function()? taskLoader;
  final RoutineRepository? routineRepository;
  final Future<List<Routine>> Function()? routineLoader;

  @override
  State<MockPaymentHomePage> createState() => _MockPaymentHomePageState();
}

enum _PaymentFlow {
  select,
  pending,
  success,
  failed,
  waiting,
  inProgress,
  challengeSuccess,
}

class _MockPaymentHomePageState extends State<MockPaymentHomePage> {
  late final MockPaymentService _paymentService;
  late final CreateChallengeService _challengeService;
  late final StartChallengeService _startChallengeService;
  late final CompleteTaskService _completeTaskService;
  TaskRepository? _taskRepository;
  RoutineRepository? _routineRepository;
  final _selectedTaskIds = <String>{};
  final _selectedRoutineIds = <String>{};
  List<Task> _tasks = [];
  List<Routine> _routines = [];
  int _amount = 1000;
  _PaymentFlow _flow = _PaymentFlow.select;
  MockPayment? _payment;
  CreateChallenge? _challenge;
  bool _isLoading = true;
  bool _isRequestInProgress = false;
  StartedChallenge? _startedChallenge;
  String? _errorMessage;
  String? _activeHoldingTaskId;
  Map<String, String> _taskStatuses = {};

  @override
  void initState() {
    super.initState();
    _paymentService = widget.paymentService ?? MockPaymentService();
    _challengeService = widget.challengeService ?? CreateChallengeService();
    _startChallengeService =
        widget.startChallengeService ?? StartChallengeService();
    _completeTaskService = widget.completeTaskService ?? CompleteTaskService();
    _taskRepository = widget.taskRepository;
    _routineRepository = widget.routineRepository;
    _loadSelectionData();
  }

  Future<void> _loadSelectionData() async {
    try {
      final results = await Future.wait<Object>([
        widget.taskLoader?.call() ??
            (_taskRepository ??= TaskRepository()).fetchTasks(),
        widget.routineLoader?.call() ??
            (_routineRepository ??= RoutineRepository()).fetchRoutines(),
      ]);
      final tasks = results[0] as List<Task>;
      final routines = results[1] as List<Routine>;
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _routines = routines;
        _selectedTaskIds
          ..clear()
          ..addAll(tasks.take(3).map((task) => task.id));
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'タスクを読み込めませんでした。もう一度お試しください。';
      });
    }
  }

  Future<void> _createPayment() async {
    if (_selectedTaskIds.isEmpty && _selectedRoutineIds.isEmpty) {
      _showMessage('TaskまたはRoutineを1つ以上選択してください。');
      return;
    }
    await _runPaymentRequest(() async {
      final payment = await _paymentService.create(_amount);
      if (!mounted) return;
      setState(() {
        _payment = payment;
        _flow = _PaymentFlow.pending;
      });
    });
  }

  Future<void> _createChallenge() async {
    final payment = _payment;
    if (payment == null || payment.status != 'SUCCESS') return;
    await _runChallengeRequest(() async {
      final challenge = await _challengeService.create(
        paymentId: payment.id,
        taskIds: _selectedTaskIds.toList(growable: false),
        routineIds: _selectedRoutineIds.toList(growable: false),
      );
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _flow = _PaymentFlow.waiting;
      });
    });
  }

  Future<void> _startChallenge() async {
    final challenge = _challenge;
    if (challenge == null || challenge.status != 'WAITING') return;
    await _runStartRequest(() async {
      final started = await _startChallengeService.start(challenge.id);
      if (!mounted) return;
      setState(() {
        _startedChallenge = started;
        _taskStatuses = {
          for (final task in challenge.challengeTasks) task.id: task.status,
        };
        _flow = _PaymentFlow.inProgress;
      });
    });
  }

  Future<bool> _completeTask(String challengeTaskId) async {
    try {
      final response = await _completeTaskService.complete(
        challengeTaskId: challengeTaskId,
      );
      if (!mounted) return true;
      if (response.isRejection) {
        setState(() {
          _errorMessage = response.rejectionUserMessage ?? 'タスクを完了できませんでした。';
        });
        return false;
      }
      setState(() {
        _taskStatuses[challengeTaskId] = 'COMPLETED';
        _errorMessage = null;
        if (response.result == 'challenge_success' ||
            _taskStatuses.values.every((s) => s == 'COMPLETED')) {
          _flow = _PaymentFlow.challengeSuccess;
        }
      });
      return true;
    } on CompleteTaskApiException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.userMessage;
        });
      }
      return false;
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'タスク完了の通信に失敗しました。';
        });
      }
      return false;
    }
  }

  Future<void> _runStartRequest(Future<void> Function() request) async {
    if (_isRequestInProgress) return;
    setState(() {
      _isRequestInProgress = true;
      _errorMessage = null;
    });
    try {
      await request();
    } on StartChallengeApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.userMessage);
    } finally {
      if (mounted) setState(() => _isRequestInProgress = false);
    }
  }

  Future<void> _runChallengeRequest(Future<void> Function() request) async {
    if (_isRequestInProgress) return;
    setState(() {
      _isRequestInProgress = true;
      _errorMessage = null;
    });
    try {
      await request();
    } on CreateChallengeApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.userMessage);
    } finally {
      if (mounted) setState(() => _isRequestInProgress = false);
    }
  }

  Future<void> _completePayment({required bool success}) async {
    final payment = _payment;
    if (payment == null) return;
    await _runPaymentRequest(() async {
      final result = success
          ? await _paymentService.success(payment.id)
          : await _paymentService.failure(payment.id);
      if (!mounted) return;
      setState(() {
        _payment = result;
        _flow = success ? _PaymentFlow.success : _PaymentFlow.failed;
      });
    });
  }

  Future<void> _runPaymentRequest(Future<void> Function() request) async {
    if (_isRequestInProgress) return;
    setState(() {
      _isRequestInProgress = true;
      _errorMessage = null;
    });
    try {
      await request();
    } on MockPaymentApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.userMessage);
    } finally {
      if (mounted) setState(() => _isRequestInProgress = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _reset() {
    setState(() {
      _flow = _PaymentFlow.select;
      _payment = null;
      _challenge = null;
      _startedChallenge = null;
      _errorMessage = null;
      _activeHoldingTaskId = null;
      _taskStatuses = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _tasks.isEmpty) {
      return _ErrorPanel(message: _errorMessage!, onRetry: _loadSelectionData);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        const Text(
          '今日のコミット',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '達成できたら全額返金。未達成なら教育ポイントになります。',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 16),
        if (_flow == _PaymentFlow.select) _buildSelection(),
        if (_flow == _PaymentFlow.pending) _buildPending(),
        if (_flow == _PaymentFlow.success) _buildSuccess(),
        if (_flow == _PaymentFlow.failed) _buildFailed(),
        if (_flow == _PaymentFlow.waiting) _buildWaiting(),
        if (_flow == _PaymentFlow.inProgress) _buildInProgress(),
        if (_flow == _PaymentFlow.challengeSuccess) _buildChallengeSuccess(),
        if (_errorMessage != null && _tasks.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InlineError(message: _errorMessage!),
        ],
      ],
    );
  }

  Widget _buildSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'コミット金額',
          child: Column(
            children: [
              Text(
                '¥$_amount',
                style: const TextStyle(
                  color: Color(0xFFFF0033),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Slider(
                min: 100,
                max: 5000,
                divisions: 49,
                value: _amount.toDouble(),
                activeColor: const Color(0xFFFF0033),
                onChanged: _isRequestInProgress
                    ? null
                    : (value) => setState(() => _amount = value.round()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('¥100', style: TextStyle(color: Colors.grey.shade600)),
                  Text('¥5000', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '対象タスク',
          subtitle: 'TaskまたはRoutineを選択してください。',
          child: Column(
            children: [
              for (final task in _tasks)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selectedTaskIds.contains(task.id),
                  title: Text(task.name),
                  onChanged: _isRequestInProgress
                      ? null
                      : (selected) => setState(() {
                          if (selected == true) {
                            _selectedTaskIds.add(task.id);
                          } else {
                            _selectedTaskIds.remove(task.id);
                          }
                        }),
                ),
              for (final routine in _routines)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.repeat),
                  value: _selectedRoutineIds.contains(routine.id),
                  title: Text(routine.name),
                  onChanged: _isRequestInProgress
                      ? null
                      : (selected) => setState(() {
                          if (selected == true) {
                            _selectedRoutineIds.add(routine.id);
                          } else {
                            _selectedRoutineIds.remove(routine.id);
                          }
                        }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Mock Payment',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '支払い成功後にチャレンジを作成できます。',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isRequestInProgress ? null : _createPayment,
                  icon: _isRequestInProgress
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_outline),
                  label: Text(
                    _isRequestInProgress
                        ? '支払いを作成中...'
                        : '¥${_amount.toString()} をコミットする',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPending() {
    return _SectionCard(
      title: '支払い確認',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StatusBadge(
            label: 'PENDING',
            color: Colors.amber,
            icon: Icons.schedule,
          ),
          const SizedBox(height: 12),
          Text(
            '¥${_payment!.amount} のMock Paymentを確認してください。',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Payment ID: ${_payment!.id}',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isRequestInProgress
                      ? null
                      : () => _completePayment(success: false),
                  child: const Text('支払い失敗'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _isRequestInProgress
                      ? null
                      : () => _completePayment(success: true),
                  child: _isRequestInProgress
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('支払い成功'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return _SectionCard(
      title: '支払い成功',
      child: Column(
        children: [
          const Icon(Icons.check_circle, size: 56, color: Colors.green),
          const SizedBox(height: 12),
          const Text('PaymentがSUCCESSになりました。'),
          const SizedBox(height: 8),
          Text(
            'Payment ID: ${_payment!.id}',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isRequestInProgress ? null : _createChallenge,
              child: _isRequestInProgress
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Challengeを作成する'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailed() {
    return _ResultCard(
      icon: Icons.error,
      color: Colors.red,
      title: '支払い失敗',
      message: 'PaymentはFAILEDになりました。再試行時は新しいPaymentを作成します。',
      payment: _payment!,
      actionLabel: '新しいPaymentで再試行',
      onAction: _reset,
    );
  }

  Widget _buildWaiting() {
    final challenge = _challenge!;
    return _SectionCard(
      title: 'Challenge作成完了',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusBadge(
            label: challenge.status,
            color: Colors.amber,
            icon: Icons.schedule,
          ),
          const SizedBox(height: 12),
          Text('¥${challenge.amount} のChallengeを作成しました。'),
          const SizedBox(height: 8),
          Text(
            '自動開始: ${_formatDateTime(challenge.autoStartAt)}\n'
            '期限: ${_formatDateTime(challenge.deadline)}',
          ),
          const SizedBox(height: 12),
          for (final task in challenge.challengeTasks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_box_outline_blank),
              title: Text(task.taskNameSnapshot),
              subtitle: Text(task.status),
            ),
          const SizedBox(height: 8),
          Text(
            'Challenge ID: ${challenge.id}',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isRequestInProgress ? null : _startChallenge,
              child: _isRequestInProgress
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('チャレンジ開始'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInProgress() {
    final challenge = _startedChallenge!;
    final tasks = _challenge?.challengeTasks ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'Challenge進行中',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StatusBadge(
                label: 'IN_PROGRESS',
                color: Colors.blue,
                icon: Icons.play_arrow,
              ),
              const SizedBox(height: 12),
              Text('¥${challenge.amount} のChallengeを開始しました。'),
              const SizedBox(height: 8),
              Text(
                '開始: ${_formatDateTime(challenge.startedAt)}\n'
                '期限: ${_formatDateTime(challenge.deadline)}',
              ),
              const SizedBox(height: 12),
              Text(
                'Challenge ID: ${challenge.id}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'タスク一覧（4秒長押しで充電・完了）',
          subtitle: '一度に1つのタスクだけ長押しできます。途中で指を離すとリセットされます。',
          child: Column(
            children: [
              for (final task in tasks)
                BatteryHoldToCompleteTile(
                  key: ValueKey(task.id),
                  taskId: task.id,
                  taskName: task.taskNameSnapshot,
                  isCompleted: _taskStatuses[task.id] == 'COMPLETED',
                  deadline: challenge.deadline,
                  isExclusiveLocked:
                      _activeHoldingTaskId != null &&
                      _activeHoldingTaskId != task.id,
                  onLockRequested: () {
                    setState(() => _activeHoldingTaskId = task.id);
                  },
                  onLockReleased: () {
                    setState(() => _activeHoldingTaskId = null);
                  },
                  onComplete: () => _completeTask(task.id),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeSuccess() {
    final challenge = _challenge;
    final amount = challenge?.amount ?? _startedChallenge?.amount ?? 1000;

    return _SectionCard(
      title: 'チャレンジ達成！ 🎉',
      child: Column(
        children: [
          const Icon(Icons.stars_rounded, size: 72, color: Colors.amber),
          const SizedBox(height: 16),
          const Text(
            'おめでとうございます！',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '全タスクを期限内に完了しました。\nコミット金額 ¥$amount は全額返金されました。',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.qr_code_2, size: 36, color: Colors.green),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QRコード開放完了',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        '実店舗や連携リーダーで読み取って利用できます。',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _reset,
              child: const Text('次のチャレンジへ進む'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${local.year}/${twoDigits(local.month)}/${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.payment,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final MockPayment payment;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      child: Column(
        children: [
          Icon(icon, size: 56, color: color),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Payment ID: ${payment.id}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(
        color: Theme.of(context).colorScheme.error,
        fontSize: 12,
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

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
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
          ],
        ),
      ),
    );
  }
}
