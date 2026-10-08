import 'package:qr/qr.dart';

import 'qr_payloads.dart';

const int kQrAssignmentSeed = 20261004;

class QrCellCoord {
  const QrCellCoord({required this.row, required this.col});

  final int row;
  final int col;

  String get key => '$row,$col';
}

class QrCellInfo {
  const QrCellInfo({
    required this.row,
    required this.col,
    required this.taskIndex,
    required this.orderInGroup,
    required this.isFinder,
  });

  final int row;
  final int col;
  final int taskIndex;
  final int orderInGroup;
  final bool isFinder;
}

class QrModel {
  const QrModel({
    required this.size,
    required this.payload,
    required this.taskCount,
    required this.cells,
    required this.allBlackCoords,
  });

  final int size;
  final String payload;
  final int taskCount;
  final List<QrCellInfo> cells;
  final List<QrCellCoord> allBlackCoords;
}

bool isFinderPatternCell(int row, int col, int size) {
  if (row < 7 && col < 7) return true;
  if (row < 7 && col >= size - 7) return true;
  if (row >= size - 7 && col < 7) return true;
  return false;
}

int _toUint32(int value) => value & 0xFFFFFFFF;

int _imul32(int a, int b) {
  final ah = (a >> 16) & 0xffff;
  final al = a & 0xffff;
  final bh = (b >> 16) & 0xffff;
  final bl = b & 0xffff;
  return ((al * bl) + (((ah * bl + al * bh) << 16))) & 0xFFFFFFFF;
}

double Function() _mulberry32(int seed) {
  var a = seed;
  return () {
    a = _toUint32(a + 0x6d2b79f5);
    var t = a;
    t = _toUint32(_imul32(t ^ (t >> 15), t | 1));
    t = _toUint32(t ^ _toUint32(t + _imul32(t ^ (t >> 7), t | 61)));
    return _toUint32(t ^ (t >> 14)) / 4294967296;
  };
}

QrCode _encodeQr(String payload) {
  return QrCode(
    payload: QrPayload.fromString(payload),
    errorCorrectLevel: QrErrorCorrectLevel.medium,
  );
}

/// Cell assignment equivalent to mock `generateQRModel` (spec ch.8.3).
QrModel generateQrModel(String payload, int taskCount) {
  final safeTaskCount = taskCount < 1 ? 1 : taskCount;
  final qrCode = _encodeQr(payload);
  final image = QrImage(qrCode);
  final size = image.moduleCount;

  final allBlackCoords = <QrCellCoord>[];
  final finderCells = <QrCellCoord>[];
  final nonFinderCells = <QrCellCoord>[];

  for (var r = 0; r < size; r++) {
    for (var c = 0; c < size; c++) {
      if (image.isDark(r, c)) {
        final coord = QrCellCoord(row: r, col: c);
        allBlackCoords.add(coord);
        if (isFinderPatternCell(r, c, size)) {
          finderCells.add(coord);
        } else {
          nonFinderCells.add(coord);
        }
      }
    }
  }

  final rng = _mulberry32(kQrAssignmentSeed);
  final shuffledNonFinder = List<QrCellCoord>.from(nonFinderCells);
  for (var i = shuffledNonFinder.length - 1; i > 0; i--) {
    final j = (rng() * (i + 1)).floor();
    final tmp = shuffledNonFinder[i];
    shuffledNonFinder[i] = shuffledNonFinder[j];
    shuffledNonFinder[j] = tmp;
  }

  final lastTaskIndex = safeTaskCount - 1;
  final groupBuckets = List<List<({QrCellCoord coord, bool isFinder})>>.generate(
    safeTaskCount,
    (_) => [],
  );

  for (var idx = 0; idx < shuffledNonFinder.length; idx++) {
    final targetGroup = idx % safeTaskCount;
    groupBuckets[targetGroup].add((coord: shuffledNonFinder[idx], isFinder: false));
  }
  for (final coord in finderCells) {
    groupBuckets[lastTaskIndex].add((coord: coord, isFinder: true));
  }

  final cells = <QrCellInfo>[];
  for (var g = 0; g < safeTaskCount; g++) {
    final bucket = List<({QrCellCoord coord, bool isFinder})>.from(groupBuckets[g]);
    bucket.sort((a, b) {
      if (a.isFinder && !b.isFinder) return 1;
      if (!a.isFinder && b.isFinder) return -1;
      return 0;
    });
    for (var order = 0; order < bucket.length; order++) {
      final item = bucket[order];
      cells.add(
        QrCellInfo(
          row: item.coord.row,
          col: item.coord.col,
          taskIndex: g,
          orderInGroup: order,
          isFinder: item.isFinder,
        ),
      );
    }
  }

  return QrModel(
    size: size,
    payload: payload,
    taskCount: safeTaskCount,
    cells: cells,
    allBlackCoords: allBlackCoords,
  );
}

QrModel generatePreviewQrModel(String challengeId, int taskCount) {
  return generateQrModel(buildPreviewQrPayload(challengeId), taskCount);
}

QrModel generateClaimQrModel({
  required String token,
  required int amount,
  int taskCount = 1,
}) {
  return generateQrModel(
    buildClaimQrPayload(token: token, amount: amount),
    taskCount,
  );
}
