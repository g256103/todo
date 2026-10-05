import React, { useMemo, useState, useEffect, useRef } from 'react';
import { ChallengeTask } from '../types';
import { generateQRModel, QRCellInfo } from '../utils/qrUtils';

interface RevealingQRProps {
  token: string;
  tasks: ChallengeTask[];
  justApprovedTaskIndex: number | null;
  onRevealFinished?: (taskIndex: number) => void;
  onAllCompletedFinished?: () => void;
}

export const RevealingQR: React.FC<RevealingQRProps> = ({
  token,
  tasks,
  justApprovedTaskIndex,
  onRevealFinished,
  onAllCompletedFinished,
}) => {
  const qrModel = useMemo(() => {
    return generateQRModel(token, Math.max(1, tasks.length));
  }, [token, tasks.length]);

  const totalTasks = tasks.length;
  const completedCount = tasks.filter((t) => t.status === 'COMPLETED').length;
  const percent = totalTasks > 0 ? Math.round((completedCount / totalTasks) * 100) : 0;

  // Track which cells are currently revealed: Set of "row,col"
  // For tasks already completed prior to current animation, their cells are revealed.
  const [revealedKeys, setRevealedKeys] = useState<Set<string>>(() => {
    const set = new Set<string>();
    tasks.forEach((t, idx) => {
      if (t.status === 'COMPLETED' && idx !== justApprovedTaskIndex) {
        qrModel.cells
          .filter((c) => c.taskIndex === idx)
          .forEach((c) => set.add(`${c.row},${c.col}`));
      }
    });
    return set;
  });

  // Track cells currently highlighting in light green during sequential reveal
  const [highlightingKeys, setHighlightingKeys] = useState<Set<string>>(new Set());
  const [isQRFlashing, setIsQRFlashing] = useState(false);

  // Sync already completed tasks if refreshed
  useEffect(() => {
    setRevealedKeys((prev) => {
      const next = new Set(prev);
      tasks.forEach((t, idx) => {
        if (t.status === 'COMPLETED' && idx !== justApprovedTaskIndex) {
          qrModel.cells
            .filter((c) => c.taskIndex === idx)
            .forEach((c) => next.add(`${c.row},${c.col}`));
        }
      });
      return next;
    });
  }, [tasks, qrModel, justApprovedTaskIndex]);

  // Handle sequential cell reveal when justApprovedTaskIndex changes
  const activeAnimRef = useRef<number | null>(null);

  useEffect(() => {
    if (justApprovedTaskIndex === null) return;

    const groupCells = qrModel.cells
      .filter((c) => c.taskIndex === justApprovedTaskIndex)
      .sort((a, b) => a.orderInGroup - b.orderInGroup);

    if (groupCells.length === 0) {
      onRevealFinished?.(justApprovedTaskIndex);
      return;
    }

    const totalDurationMs = 800; // Requirement: ~800ms total
    const intervalMs = Math.max(6, Math.floor(totalDurationMs / groupCells.length));

    let currentIndex = 0;

    const interval = window.setInterval(() => {
      if (currentIndex >= groupCells.length) {
        window.clearInterval(interval);

        const isLastTask = justApprovedTaskIndex === totalTasks - 1;
        if (isLastTask) {
          // Requirement: "完成の瞬間にだけ、QR全体が軽く光る(1回、400ms程度)"
          setIsQRFlashing(true);
          setTimeout(() => {
            setIsQRFlashing(false);
            onAllCompletedFinished?.();
          }, 400);
        }

        onRevealFinished?.(justApprovedTaskIndex);
        return;
      }

      // Reveal in chunks if group is very large, or 1 cell per tick
      const cell = groupCells[currentIndex];
      const key = `${cell.row},${cell.col}`;

      setRevealedKeys((prev) => {
        const next = new Set(prev);
        next.add(key);
        return next;
      });

      // Transient light-green highlight
      setHighlightingKeys((prev) => {
        const next = new Set(prev);
        next.add(key);
        return next;
      });

      // Fade out highlight after 120ms
      setTimeout(() => {
        setHighlightingKeys((prev) => {
          const next = new Set(prev);
          next.delete(key);
          return next;
        });
      }, 120);

      currentIndex++;
    }, intervalMs);

    return () => {
      window.clearInterval(interval);
    };
  }, [justApprovedTaskIndex, qrModel, totalTasks, onRevealFinished, onAllCompletedFinished]);

  return (
    <div className="flex flex-col items-center justify-center my-1 select-none">
      {/* QR Container: ~70% screen width (~240px), white background, adequate quiet zone */}
      <div
        className={`relative w-[238px] h-[238px] bg-white rounded-2xl p-3 shadow-xs border border-black/[0.08] flex items-center justify-center transition-all duration-300 ${
          isQRFlashing ? 'ring-4 ring-[#34C759] shadow-[0_0_20px_rgba(52,199,89,0.5)]' : ''
        }`}
      >
        {/* Flash Overlay */}
        {isQRFlashing && (
          <div className="absolute inset-0 bg-[#34C759]/20 rounded-2xl pointer-events-none z-30 transition-opacity duration-400" />
        )}

        <svg
          viewBox={`0 0 ${qrModel.size} ${qrModel.size}`}
          className="w-full h-full shape-rendering-crispEdges"
        >
          {/* Background white */}
          <rect x="0" y="0" width={qrModel.size} height={qrModel.size} fill="#FFFFFF" />

          {/* Render all QR cell positions */}
          {qrModel.allBlackCoords.map(({ row, col }) => {
            const key = `${row},${col}`;
            const isRevealed = revealedKeys.has(key);
            const isHighlighting = highlightingKeys.has(key);

            if (!isRevealed) {
              // Unrevealed cell: faint gray point (opacity ~8%)
              return (
                <rect
                  key={key}
                  x={col}
                  y={row}
                  width="1"
                  height="1"
                  fill="rgba(28, 28, 30, 0.08)"
                />
              );
            }

            // Revealed cell: #1C1C1E with optional light green highlight halo
            return (
              <g key={key}>
                {isHighlighting && (
                  <rect
                    x={col - 0.25}
                    y={row - 0.25}
                    width="1.5"
                    height="1.5"
                    fill="#34C759"
                    opacity="0.65"
                    rx="0.2"
                  />
                )}
                <rect
                  x={col}
                  y={row}
                  width="1"
                  height="1"
                  fill={isHighlighting ? '#28A745' : '#1C1C1E'}
                />
              </g>
            );
          })}
        </svg>
      </div>

      {/* Progress label below QR */}
      <div className="mt-2 text-center">
        <div className="flex items-center justify-center gap-1.5 text-xs text-[#1C1C1E] font-bold">
          <span className="tabular-nums font-mono text-[13px]">
            {completedCount} / {totalTasks} 完了
          </span>
          <span className="text-[#8E8E93] text-[11px] font-normal tabular-nums">
            ({percent}%)
          </span>
        </div>
        <p className="text-[10px] text-[#8E8E93] mt-0.5">
          {completedCount === totalTasks
            ? '全セル開放・QR読み取り可能'
            : completedCount === 0
            ? 'タスク完了ごとにQRセルが浮かび上がります'
            : '完了タスクのセルが蓄積中…'}
        </p>
      </div>
    </div>
  );
};
