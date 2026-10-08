import 'dart:async';

import 'package:flutter/material.dart';

import 'qr_model.dart';

/// IN_PROGRESS preview QR with per-task cell reveal (spec ch.8.4).
class RevealingQrWidget extends StatefulWidget {
  const RevealingQrWidget({
    super.key,
    required this.challengeId,
    required this.taskStatuses,
    this.justApprovedTaskIndex,
    this.onRevealFinished,
    this.onAllCompletedFinished,
    this.instantReveal = false,
  });

  final String challengeId;
  final List<String> taskStatuses;
  final int? justApprovedTaskIndex;
  final void Function(int taskIndex)? onRevealFinished;
  final VoidCallback? onAllCompletedFinished;
  final bool instantReveal;

  @override
  State<RevealingQrWidget> createState() => _RevealingQrWidgetState();
}

class _RevealingQrWidgetState extends State<RevealingQrWidget> {
  static const _black = Color(0xFF1C1C1E);
  static const _green = Color(0xFF34C759);

  late QrModel _model;
  final Set<String> _revealedKeys = {};
  final Set<String> _highlightingKeys = {};
  bool _isQrFlashing = false;
  Timer? _revealTimer;
  int? _activeAnimTaskIndex;

  @override
  void initState() {
    super.initState();
    _model = generatePreviewQrModel(
      widget.challengeId,
      widget.taskStatuses.length,
    );
    _seedRevealedFromCompleted(excludeIndex: widget.justApprovedTaskIndex);
    _scheduleRevealIfNeeded(widget.justApprovedTaskIndex);
  }

  void _scheduleRevealIfNeeded(int? taskIndex) {
    if (taskIndex == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.justApprovedTaskIndex == taskIndex &&
          _activeAnimTaskIndex != taskIndex) {
        _startReveal(taskIndex);
      }
    });
  }

  @override
  void didUpdateWidget(covariant RevealingQrWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final taskCount = widget.taskStatuses.length;
    if (oldWidget.challengeId != widget.challengeId ||
        oldWidget.taskStatuses.length != taskCount) {
      _model = generatePreviewQrModel(widget.challengeId, taskCount);
      _revealedKeys.clear();
      _highlightingKeys.clear();
      _seedRevealedFromCompleted(excludeIndex: widget.justApprovedTaskIndex);
    } else {
      _seedRevealedFromCompleted(excludeIndex: widget.justApprovedTaskIndex);
    }

    if (widget.justApprovedTaskIndex != oldWidget.justApprovedTaskIndex) {
      _scheduleRevealIfNeeded(widget.justApprovedTaskIndex);
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  void _seedRevealedFromCompleted({int? excludeIndex}) {
    for (var idx = 0; idx < widget.taskStatuses.length; idx++) {
      if (widget.taskStatuses[idx] == 'COMPLETED' && idx != excludeIndex) {
        for (final cell in _model.cells.where((c) => c.taskIndex == idx)) {
          _revealedKeys.add('${cell.row},${cell.col}');
        }
      }
    }
  }

  void _startReveal(int taskIndex) {
    _revealTimer?.cancel();
    _activeAnimTaskIndex = taskIndex;

    if (widget.instantReveal) {
      final groupCells = _model.cells.where((c) => c.taskIndex == taskIndex);
      for (final cell in groupCells) {
        _revealedKeys.add('${cell.row},${cell.col}');
      }
      _finishReveal(
        taskIndex,
        isLastTask: taskIndex == widget.taskStatuses.length - 1,
        skipFlashDelay: true,
      );
      return;
    }

    final groupCells = _model.cells
        .where((c) => c.taskIndex == taskIndex)
        .toList()
      ..sort((a, b) => a.orderInGroup.compareTo(b.orderInGroup));

    if (groupCells.isEmpty) {
      _finishReveal(taskIndex, isLastTask: taskIndex == widget.taskStatuses.length - 1);
      return;
    }

    const totalDurationMs = 800;
    final intervalMs = (totalDurationMs / groupCells.length)
        .floor()
        .clamp(6, totalDurationMs);
    final isLastTask = taskIndex == widget.taskStatuses.length - 1;

    void revealStep(int currentIndex) {
      if (currentIndex >= groupCells.length) {
        _finishReveal(taskIndex, isLastTask: isLastTask);
        return;
      }

      final cell = groupCells[currentIndex];
      final key = '${cell.row},${cell.col}';
      setState(() {
        _revealedKeys.add(key);
        _highlightingKeys.add(key);
      });

      Timer(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() => _highlightingKeys.remove(key));
      });

      _revealTimer = Timer(Duration(milliseconds: intervalMs), () {
        if (!mounted) return;
        revealStep(currentIndex + 1);
      });
    }

    revealStep(0);
  }

  void _finishReveal(
    int taskIndex, {
    required bool isLastTask,
    bool skipFlashDelay = false,
  }) {
    widget.onRevealFinished?.call(taskIndex);
    _activeAnimTaskIndex = null;
    if (isLastTask) {
      if (skipFlashDelay) {
        widget.onAllCompletedFinished?.call();
        return;
      }
      setState(() => _isQrFlashing = true);
      Timer(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() => _isQrFlashing = false);
        widget.onAllCompletedFinished?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalTasks = widget.taskStatuses.length;
    final completedCount = widget.taskStatuses
        .where((s) => s == 'COMPLETED')
        .length;
    final percent = totalTasks > 0
        ? ((completedCount / totalTasks) * 100).round()
        : 0;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 238,
          height: 238,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            boxShadow: _isQrFlashing
                ? [
                    BoxShadow(
                      color: _green.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_isQrFlashing)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              CustomPaint(
                painter: _QrRevealPainter(
                  model: _model,
                  revealedKeys: _revealedKeys,
                  highlightingKeys: _highlightingKeys,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$completedCount / $totalTasks 完了 ($percent%)',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: _black,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          completedCount == totalTasks
              ? '全セル開放（プレビュー・読取不可）'
              : completedCount == 0
              ? 'タスク完了ごとにQRセルが浮かび上がります'
              : '完了タスクのセルが蓄積中…',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _QrRevealPainter extends CustomPainter {
  _QrRevealPainter({
    required this.model,
    required this.revealedKeys,
    required this.highlightingKeys,
  });

  final QrModel model;
  final Set<String> revealedKeys;
  final Set<String> highlightingKeys;

  static const _black = Color(0xFF1C1C1E);
  static const _green = Color(0xFF34C759);

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / model.size;
    final bg = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, bg);

    for (final coord in model.allBlackCoords) {
      final key = coord.key;
      final rect = Rect.fromLTWH(
        coord.col * cellSize,
        coord.row * cellSize,
        cellSize,
        cellSize,
      );
      final isRevealed = revealedKeys.contains(key);
      if (!isRevealed) {
        canvas.drawRect(
          rect,
          Paint()..color = _black.withValues(alpha: 0.08),
        );
        continue;
      }
      final isHighlighting = highlightingKeys.contains(key);
      if (isHighlighting) {
        final halo = Rect.fromCenter(
          center: rect.center,
          width: cellSize * 1.5,
          height: cellSize * 1.5,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(halo, Radius.circular(cellSize * 0.2)),
          Paint()..color = _green.withValues(alpha: 0.65),
        );
      }
      canvas.drawRect(
        rect,
        Paint()..color = isHighlighting ? const Color(0xFF28A745) : _black,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _QrRevealPainter oldDelegate) {
    return oldDelegate.revealedKeys != revealedKeys ||
        oldDelegate.highlightingKeys != highlightingKeys ||
        oldDelegate.model != model;
  }
}
