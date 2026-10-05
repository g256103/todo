import QRCode from 'qrcode';

export interface QRCellInfo {
  row: number;
  col: number;
  taskIndex: number;
  orderInGroup: number;
  isFinder: boolean;
}

export interface QRModel {
  size: number;
  token: string;
  taskCount: number;
  cells: QRCellInfo[];
  allBlackCoords: { row: number; col: number }[];
}

// Simple deterministic PRNG (Mulberry32)
function mulberry32(a: number) {
  return function () {
    let t = (a += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function isFinderPatternCell(row: number, col: number, size: number): boolean {
  // Top-left 7x7 finder
  if (row < 7 && col < 7) return true;
  // Top-right 7x7 finder
  if (row < 7 && col >= size - 7) return true;
  // Bottom-left 7x7 finder
  if (row >= size - 7 && col < 7) return true;
  return false;
}

export function generateQRModel(token: string, taskCount: number): QRModel {
  const qr = QRCode.create(token, { errorCorrectionLevel: 'M' });
  const size = qr.modules.size;

  const allBlackCoords: { row: number; col: number }[] = [];
  const finderCells: { row: number; col: number }[] = [];
  const nonFinderCells: { row: number; col: number }[] = [];

  for (let r = 0; r < size; r++) {
    for (let c = 0; c < size; c++) {
      if (qr.modules.get(r, c)) {
        allBlackCoords.push({ row: r, col: c });
        if (isFinderPatternCell(r, c, size)) {
          finderCells.push({ row: r, col: c });
        } else {
          nonFinderCells.push({ row: r, col: c });
        }
      }
    }
  }

  // Deterministic shuffle of non-finder cells with fixed seed
  const rng = mulberry32(20261004);
  const shuffledNonFinder = [...nonFinderCells];
  for (let i = shuffledNonFinder.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [shuffledNonFinder[i], shuffledNonFinder[j]] = [shuffledNonFinder[j], shuffledNonFinder[i]];
  }

  // We assign non-finder cells among task groups 0..taskCount-1
  // All finder cells go strictly to the LAST task (taskCount - 1)
  const lastTaskIndex = Math.max(0, taskCount - 1);
  const cells: QRCellInfo[] = [];

  // Group buckets
  const groupBuckets: { row: number; col: number; isFinder: boolean }[][] = Array.from(
    { length: taskCount },
    () => []
  );

  // Distribute non-finder cells across all tasks (or biased slightly towards 0..last-1 so last task isn't overwhelmingly heavy)
  shuffledNonFinder.forEach((coord, idx) => {
    // Round-robin assignment across all groups
    const targetGroup = idx % taskCount;
    groupBuckets[targetGroup].push({ ...coord, isFinder: false });
  });

  // Put ALL finder pattern cells into the last task group
  finderCells.forEach((coord) => {
    groupBuckets[lastTaskIndex].push({ ...coord, isFinder: true });
  });

  // Assign order within each group
  for (let g = 0; g < taskCount; g++) {
    // Sort finder cells to appear last in the last task
    groupBuckets[g].sort((a, b) => {
      if (a.isFinder && !b.isFinder) return 1;
      if (!a.isFinder && b.isFinder) return -1;
      return 0;
    });

    groupBuckets[g].forEach((item, order) => {
      cells.push({
        row: item.row,
        col: item.col,
        taskIndex: g,
        orderInGroup: order,
        isFinder: item.isFinder,
      });
    });
  }

  return {
    size,
    token,
    taskCount,
    cells,
    allBlackCoords,
  };
}
