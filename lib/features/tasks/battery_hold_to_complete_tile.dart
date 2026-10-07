import 'dart:math' as math;

import 'package:flutter/material.dart';

class BatteryPainter extends CustomPainter {
  BatteryPainter({
    required this.progress,
    required this.borderColor,
    required this.fillColor,
    this.isFullShine = false,
  });

  final double progress; // 0.0 ~ 1.0
  final Color borderColor;
  final Color fillColor;
  final bool isFullShine;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.0;
    const terminalWidth = 3.0;
    const terminalHeightRatio = 0.45;
    const cornerRadius = 4.0;

    final bodyWidth = size.width - terminalWidth - 2.0;
    final bodyHeight = size.height;

    // バッテリー外枠
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        bodyWidth - strokeWidth,
        bodyHeight - strokeWidth,
      ),
      const Radius.circular(cornerRadius),
    );
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRRect(bodyRect, borderPaint);

    // プラス端子（右側突起）
    final terminalHeight = bodyHeight * terminalHeightRatio;
    final terminalTop = (bodyHeight - terminalHeight) / 2;
    final terminalRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bodyWidth, terminalTop, terminalWidth, terminalHeight),
      const Radius.circular(1.5),
    );
    final terminalPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(terminalRect, terminalPaint);

    // 内部ゲージ（充電）
    if (progress > 0) {
      final innerPadding = strokeWidth + 1.5;
      final maxFillWidth = bodyWidth - (innerPadding * 2);
      final currentFillWidth = maxFillWidth * progress.clamp(0.0, 1.0);
      final innerHeight = bodyHeight - (innerPadding * 2);

      final fillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          innerPadding,
          innerPadding,
          currentFillWidth,
          innerHeight,
        ),
        Radius.circular(math.max(1.0, cornerRadius - 2)),
      );
      final fillPaint = Paint()
        ..color = isFullShine ? fillColor.withValues(alpha: 0.9) : fillColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(fillRect, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BatteryPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.isFullShine != isFullShine;
  }
}

class BatteryHoldToCompleteTile extends StatefulWidget {
  const BatteryHoldToCompleteTile({
    super.key,
    required this.taskId,
    required this.taskName,
    required this.isCompleted,
    required this.deadline,
    required this.onComplete,
    this.isExclusiveLocked = false,
    this.onLockRequested,
    this.onLockReleased,
  });

  final String taskId;
  final String taskName;
  final bool isCompleted;
  final DateTime deadline;
  final Future<bool> Function() onComplete;
  final bool isExclusiveLocked;
  final VoidCallback? onLockRequested;
  final VoidCallback? onLockReleased;

  @override
  State<BatteryHoldToCompleteTile> createState() =>
      _BatteryHoldToCompleteTileState();
}

class _BatteryHoldToCompleteTileState extends State<BatteryHoldToCompleteTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isHolding = false;
  bool _isProcessingServer = false;
  bool _isFailedReject = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..addListener(() {
            setState(() {});
          });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isHolding) {
        _triggerServerComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isDeadlineTooClose() {
    final remaining = widget.deadline.difference(DateTime.now());
    return remaining.inSeconds < 5;
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (widget.isCompleted ||
        _isProcessingServer ||
        widget.isExclusiveLocked ||
        _isDeadlineTooClose()) {
      return;
    }
    widget.onLockRequested?.call();
    setState(() {
      _isHolding = true;
      _isFailedReject = false;
    });
    _controller.forward(from: 0.0);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _cancelHold();
  }

  void _onLongPressCancel() {
    _cancelHold();
  }

  void _cancelHold() {
    if (!_isHolding) return;
    if (!_isProcessingServer) {
      _controller.reset();
      widget.onLockReleased?.call();
      setState(() {
        _isHolding = false;
      });
    }
  }

  Future<void> _triggerServerComplete() async {
    setState(() {
      _isProcessingServer = true;
    });

    final success = await widget.onComplete();

    if (!mounted) return;

    if (success) {
      widget.onLockReleased?.call();
      setState(() {
        _isHolding = false;
        _isProcessingServer = false;
      });
    } else {
      // 拒否時は逆再生アニメーション
      setState(() {
        _isFailedReject = true;
        _isProcessingServer = false;
      });
      await _controller.reverse();
      if (!mounted) return;
      widget.onLockReleased?.call();
      setState(() {
        _isHolding = false;
        _isFailedReject = false;
      });
    }
  }

  Future<void> _showAccessibleDialog() async {
    if (widget.isCompleted || _isProcessingServer || _isDeadlineTooClose()) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('タスクの完了'),
        content: Text('「${widget.taskName}」を完了しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('完了する'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      widget.onLockRequested?.call();
      setState(() {
        _isProcessingServer = true;
      });
      await widget.onComplete();
      if (mounted) {
        widget.onLockReleased?.call();
        setState(() {
          _isProcessingServer = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocked = widget.isExclusiveLocked && !_isHolding;
    final isDeadlineRestricted = _isDeadlineTooClose() && !widget.isCompleted;

    final progress = widget.isCompleted ? 1.0 : _controller.value;
    final fillColor = widget.isCompleted
        ? Colors.green
        : (_isFailedReject ? Colors.red : Colors.green.shade600);

    return Semantics(
      label: '${widget.taskName} ${widget.isCompleted ? "完了済み" : "4秒長押しで完了"}',
      child: GestureDetector(
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        onLongPressCancel: _onLongPressCancel,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: widget.isCompleted
                ? Colors.green.withValues(alpha: 0.08)
                : (isLocked
                      ? Colors.grey.withValues(alpha: 0.08)
                      : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isCompleted
                  ? Colors.green.shade300
                  : Colors.grey.shade300,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: SizedBox(
              width: 38,
              height: 22,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(38, 22),
                    painter: BatteryPainter(
                      progress: progress,
                      borderColor: widget.isCompleted
                          ? Colors.green
                          : (isLocked
                                ? Colors.grey.shade400
                                : Colors.grey.shade700),
                      fillColor: fillColor,
                      isFullShine: progress >= 1.0,
                    ),
                  ),
                  if (_isProcessingServer)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            title: Text(
              widget.taskName,
              style: TextStyle(
                decoration: widget.isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                color: widget.isCompleted
                    ? Colors.grey.shade600
                    : (isLocked ? Colors.grey.shade500 : Colors.black87),
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: widget.isCompleted
                ? const Text(
                    '完了済み',
                    style: TextStyle(color: Colors.green, fontSize: 11),
                  )
                : (isDeadlineRestricted
                      ? const Text(
                          '締切直前のため操作不可',
                          style: TextStyle(color: Colors.red, fontSize: 11),
                        )
                      : (_isHolding
                            ? Text(
                                '長押し中... ${(progress * 4).toStringAsFixed(1)}s / 4.0s',
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontSize: 11,
                                ),
                              )
                            : const Text(
                                '4秒長押しで完了',
                                style: TextStyle(fontSize: 11),
                              ))),
            trailing: IconButton(
              icon: const Icon(Icons.accessibility, size: 20),
              tooltip: '支援機能用完了ボタン',
              onPressed:
                  (widget.isCompleted || isLocked || isDeadlineRestricted)
                  ? null
                  : _showAccessibleDialog,
            ),
          ),
        ),
      ),
    );
  }
}
