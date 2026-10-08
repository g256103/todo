import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'qr_model.dart';

/// SUCCESS claim QR with 4×4 puzzle assembly (spec ch.8.5).
class ClaimQrPanel extends StatefulWidget {
  const ClaimQrPanel({
    super.key,
    required this.token,
    required this.amount,
    this.qrStatus = 'AVAILABLE',
    this.assembleImmediately = false,
  });

  final String token;
  final int amount;
  final String qrStatus;
  final bool assembleImmediately;

  @override
  State<ClaimQrPanel> createState() => _ClaimQrPanelState();
}

class _ClaimQrPanelState extends State<ClaimQrPanel>
    with SingleTickerProviderStateMixin {
  static const _boxSize = 220.0;
  static const _grid = 4;
  bool _puzzleAssembled = false;

  late QrModel _model;
  late final List<_PuzzlePiece> _pieces;

  @override
  void initState() {
    super.initState();
    _model = generateClaimQrModel(token: widget.token, amount: widget.amount);
    _pieces = _buildPuzzlePieces();
    _puzzleAssembled = widget.assembleImmediately;
    if (!widget.assembleImmediately) {
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _puzzleAssembled = true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ClaimQrPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token || oldWidget.amount != widget.amount) {
      _model = generateClaimQrModel(token: widget.token, amount: widget.amount);
    }
  }

  List<_PuzzlePiece> _buildPuzzlePieces() {
    const scatter = <(double, double, double)>[
      (-120, -140, -25),
      (30, -160, 15),
      (110, -130, -20),
      (140, -80, 30),
      (-150, -40, -35),
      (-60, -30, 12),
      (70, -20, -18),
      (150, -10, 25),
      (-140, 40, 20),
      (-50, 50, -15),
      (60, 60, 28),
      (130, 70, -22),
      (-110, 130, -30),
      (-20, 150, 18),
      (80, 140, -12),
      (140, 120, 32),
    ];
    final pieces = <_PuzzlePiece>[];
    for (var r = 0; r < _grid; r++) {
      for (var c = 0; c < _grid; c++) {
        final id = r * _grid + c;
        final s = scatter[id % scatter.length];
        pieces.add(
          _PuzzlePiece(id: id, row: r, col: c, rx: s.$1, ry: s.$2, rot: s.$3),
        );
      }
    }
    return pieces;
  }

  @override
  Widget build(BuildContext context) {
    final tileSize = _boxSize / _grid;
    final statusLabel = widget.qrStatus == 'USED' ? '利用済み' : '利用可能';

    return Column(
      children: [
        Text(
          '達成証明 QRコード（$statusLabel）',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: _boxSize + 24,
          height: _boxSize + 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!_puzzleAssembled)
                for (final piece in _pieces)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOut,
                    left: 12 + piece.col * tileSize + (_puzzleAssembled ? 0 : piece.rx),
                    top: 12 + piece.row * tileSize + (_puzzleAssembled ? 0 : piece.ry),
                    width: tileSize,
                    height: tileSize,
                    child: Transform.rotate(
                      angle: _puzzleAssembled ? 0 : piece.rot * math.pi / 180,
                      child: ClipRect(
                        child: OverflowBox(
                          minWidth: _boxSize,
                          maxWidth: _boxSize,
                          minHeight: _boxSize,
                          maxHeight: _boxSize,
                          alignment: Alignment.topLeft,
                          child: Transform.translate(
                            offset: Offset(-piece.col * tileSize, -piece.row * tileSize),
                            child: CustomPaint(
                              size: const Size(_boxSize, _boxSize),
                              painter: _ClaimQrPainter(model: _model),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _puzzleAssembled ? 1 : 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CustomPaint(
                    size: const Size(_boxSize, _boxSize),
                    painter: _ClaimQrPainter(model: _model),
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

class _PuzzlePiece {
  const _PuzzlePiece({
    required this.id,
    required this.row,
    required this.col,
    required this.rx,
    required this.ry,
    required this.rot,
  });

  final int id;
  final int row;
  final int col;
  final double rx;
  final double ry;
  final double rot;
}

class _ClaimQrPainter extends CustomPainter {
  _ClaimQrPainter({required this.model});

  final QrModel model;

  @override
  void paint(Canvas canvas, Size size) {
    final quiet = 2.0;
    final moduleSize = (size.width - quiet * 2) / model.size;
    final offset = Offset(quiet, quiet);

    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    final paint = Paint()..color = const Color(0xFF1C1C1E);
    for (final coord in model.allBlackCoords) {
      final rect = Rect.fromLTWH(
        offset.dx + coord.col * moduleSize,
        offset.dy + coord.row * moduleSize,
        moduleSize,
        moduleSize,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ClaimQrPainter oldDelegate) =>
      oldDelegate.model.payload != model.payload;
}
