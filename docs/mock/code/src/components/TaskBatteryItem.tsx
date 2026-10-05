import React, { useState, useRef, useEffect, useCallback } from 'react';
import { Check, Loader2, AlertCircle, Clock } from 'lucide-react';
import { ChallengeTask } from '../types';

interface TaskBatteryItemProps {
  task: ChallengeTask;
  activePressingId: string | null;
  onPressStart: (taskId: string) => void;
  onPressEnd: () => void;
  onComplete: (taskId: string) => Promise<boolean>;
  onServerRejectTriggered?: (taskId: string, message: string) => void;
  isSimulatingReject: boolean;
  deadlineLessThan5s: boolean;
  accessibleMode: boolean;
  disabled?: boolean;
  forcedProgress?: number | null; // For dev menu control (0%, 50%, 100%)
  forceRejectTrigger?: number; // Counter to trigger reject animation from dev menu
}

export const TaskBatteryItem: React.FC<TaskBatteryItemProps> = ({
  task,
  activePressingId,
  onPressStart,
  onPressEnd,
  onComplete,
  onServerRejectTriggered,
  isSimulatingReject,
  deadlineLessThan5s,
  accessibleMode,
  disabled = false,
  forcedProgress = null,
  forceRejectTrigger = 0,
}) => {
  const [progress, setProgress] = useState(0); // 0 to 100
  const [isVerifying, setIsVerifying] = useState(false);
  const [isFlashing, setIsFlashing] = useState(false);
  const [isRejecting, setIsRejecting] = useState(false);
  const [showConfirmModal, setShowConfirmModal] = useState(false);

  const startTimeRef = useRef<number | null>(null);
  const animFrameRef = useRef<number | null>(null);
  const isPressingCurrentTask = activePressingId === task.id;
  const isOtherTaskPressing = activePressingId !== null && activePressingId !== task.id;

  const isCompleted = task.status === 'COMPLETED';
  const cannotPress =
    disabled || isCompleted || isOtherTaskPressing || deadlineLessThan5s || isVerifying || isRejecting;

  // React to forcedProgress from DevMenu when this task is active
  useEffect(() => {
    if (isPressingCurrentTask && forcedProgress !== null && forcedProgress !== undefined) {
      setProgress(forcedProgress);
      if (forcedProgress >= 100) {
        handleHoldSuccess();
      }
    }
  }, [forcedProgress, isPressingCurrentTask]);

  // React to forced reject trigger from DevMenu
  const prevRejectTriggerRef = useRef(forceRejectTrigger);
  useEffect(() => {
    if (forceRejectTrigger > prevRejectTriggerRef.current && isPressingCurrentTask) {
      handleServerReject();
    }
    prevRejectTriggerRef.current = forceRejectTrigger;
  }, [forceRejectTrigger, isPressingCurrentTask]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (animFrameRef.current) cancelAnimationFrame(animFrameRef.current);
    };
  }, []);

  // Spec: "指を離す/キャンセル/他のタスク選択などで中断したら、液体を即座に0へリセットする(アニメーションなしで消える)"
  const resetProgress = useCallback(() => {
    if (animFrameRef.current) {
      cancelAnimationFrame(animFrameRef.current);
      animFrameRef.current = null;
    }
    startTimeRef.current = null;
    setProgress(0);
    onPressEnd();
  }, [onPressEnd]);

  // Spec: "拒否(デモで再現可能): 液体の水位が逆再生するように下がって0に戻る(約600ms)。その後Snackbarでエラーを表示"
  const handleServerReject = useCallback(() => {
    setIsVerifying(false);
    setIsRejecting(true);

    // Smoothly animate down to 0% over 600ms
    setProgress(0);

    setTimeout(() => {
      setIsRejecting(false);
      onPressEnd();
      if (onServerRejectTriggered) {
        onServerRejectTriggered(
          task.id,
          'サーバー検証失敗: 締切超過または判定不能により完了が拒否されました'
        );
      }
    }, 600);
  }, [onPressEnd, onServerRejectTriggered, task.id]);

  const handleHoldSuccess = useCallback(async () => {
    if (animFrameRef.current) {
      cancelAnimationFrame(animFrameRef.current);
      animFrameRef.current = null;
    }
    setProgress(100);

    // Spec: "100%に到達した瞬間だけ、行の縁が軽く光る(1回、300ms程度)"
    setIsFlashing(true);
    setTimeout(() => setIsFlashing(false), 300);

    // Spec: "液体が満タンの状態を維持し、行の上にローディングを重ねる(「サーバー確認中」、約1秒)"
    setIsVerifying(true);

    if (navigator.vibrate) {
      try {
        navigator.vibrate(60);
      } catch {
        // ignore
      }
    }

    setTimeout(async () => {
      if (isSimulatingReject) {
        handleServerReject();
      } else {
        const success = await onComplete(task.id);
        setIsVerifying(false);
        if (!success) {
          handleServerReject();
        } else {
          // Spec: "承認: 行全体が緑の面になり、チェックマークを表示。続けてC(QRのセルが現れる)を再生する"
          onPressEnd();
        }
      }
    }, 1000);
  }, [handleServerReject, isSimulatingReject, onComplete, onPressEnd, task.id]);

  // Linear progress tick over 4000ms
  const tick = useCallback(
    (timestamp: number) => {
      if (!startTimeRef.current) {
        startTimeRef.current = timestamp;
      }
      const elapsed = timestamp - startTimeRef.current;
      const calculatedProgress = Math.min((elapsed / 4000) * 100, 100);
      setProgress(calculatedProgress);

      if (calculatedProgress >= 100) {
        handleHoldSuccess();
      } else {
        animFrameRef.current = requestAnimationFrame(tick);
      }
    },
    [handleHoldSuccess]
  );

  const handlePointerDown = (e: React.PointerEvent) => {
    if (accessibleMode) return;
    if (cannotPress) return;

    e.currentTarget.setPointerCapture?.(e.pointerId);

    onPressStart(task.id);
    startTimeRef.current = performance.now();
    setProgress(0);
    setIsRejecting(false);
    animFrameRef.current = requestAnimationFrame(tick);
  };

  const handlePointerUpOrCancel = (e: React.PointerEvent) => {
    if (accessibleMode) return;
    if (!isPressingCurrentTask || isVerifying || isRejecting) return;

    if (e.currentTarget.hasPointerCapture?.(e.pointerId)) {
      e.currentTarget.releasePointerCapture(e.pointerId);
    }

    // Spec: "指を離す/キャンセル/他のタスク選択などで中断したら、液体を即座に0へリセットする(アニメーションなしで消える)"
    resetProgress();
  };

  // Accessibility alternative: confirm dialog
  const handleAccessibleComplete = async () => {
    setShowConfirmModal(false);
    setIsVerifying(true);
    setTimeout(async () => {
      if (isSimulatingReject) {
        handleServerReject();
      } else {
        await onComplete(task.id);
        setIsVerifying(false);
      }
    }, 700);
  };

  return (
    <>
      <div
        onPointerDown={handlePointerDown}
        onPointerUp={handlePointerUpOrCancel}
        onPointerCancel={handlePointerUpOrCancel}
        onContextMenu={(e) => e.preventDefault()}
        className={`relative w-full rounded-2xl overflow-hidden select-none touch-none border transition-all duration-150 min-h-[64px] ${
          isCompleted
            ? 'bg-[#34C759] border-[#34C759] text-white shadow-xs'
            : isOtherTaskPressing
            ? 'bg-slate-100/90 border-slate-200 text-slate-400 opacity-35 grayscale pointer-events-none'
            : deadlineLessThan5s
            ? 'bg-white border-slate-200 opacity-50 cursor-not-allowed'
            : isPressingCurrentTask
            ? 'bg-white border-[#1C1C1E] shadow-md scale-[0.99]'
            : 'bg-white border-black/[0.08] hover:border-black/20 text-[#1C1C1E] shadow-2xs'
        } ${isFlashing ? 'ring-3 ring-[#34C759] shadow-[0_0_12px_rgba(52,199,89,0.5)]' : ''}`}
      >
        {/* ========================================================= */}
        {/* A. LIQUID CHARGING LAYER (Bottom-to-Top with Wavy Surface) */}
        {/* ========================================================= */}
        {!isCompleted && (progress > 0 || isRejecting) && (
          <div
            className={`absolute bottom-0 left-0 right-0 pointer-events-none overflow-hidden ${
              isRejecting ? 'transition-[height] duration-600 ease-in-out' : ''
            }`}
            style={{ height: `${progress}%` }}
          >
            {/* Liquid Body (solid #34C759 with 85% opacity) */}
            <div
              className="absolute inset-0 top-2"
              style={{ backgroundColor: 'rgba(52, 199, 89, 0.85)' }}
            />

            {/* Wave 1: Back Wave (#34C759 opacity 45%) */}
            <div className="absolute top-0 left-0 w-[200%] h-3 pointer-events-none animate-wave-back -translate-y-1/2">
              <svg viewBox="0 0 200 20" preserveAspectRatio="none" className="w-full h-full">
                <path
                  d="M 0 10 Q 25 3, 50 10 T 100 10 T 150 10 T 200 10 V 20 H 0 Z"
                  fill="rgba(52, 199, 89, 0.45)"
                />
              </svg>
            </div>

            {/* Wave 2: Front Wave (#34C759 opacity 85%) */}
            <div className="absolute top-0 left-0 w-[200%] h-3 pointer-events-none animate-wave-front -translate-y-1/2">
              <svg viewBox="0 0 200 20" preserveAspectRatio="none" className="w-full h-full">
                <path
                  d="M 0 10 Q 25 0, 50 10 T 100 10 T 150 10 T 200 10 V 20 H 0 Z"
                  fill="rgba(52, 199, 89, 0.85)"
                />
              </svg>
            </div>
          </div>
        )}

        {/* ========================================================= */}
        {/* B. SERVER VERIFICATION OVERLAY (~1s) */}
        {/* ========================================================= */}
        {isVerifying && (
          <div className="absolute inset-0 bg-white/85 backdrop-blur-xs flex items-center justify-center z-30 pointer-events-none">
            <div className="flex items-center gap-2 text-xs font-semibold text-[#1C1C1E]">
              <Loader2 className="w-4 h-4 animate-spin text-[#34C759]" />
              <span>サーバー確認中…</span>
            </div>
          </div>
        )}

        {/* ========================================================= */}
        {/* FOREGROUND TASK CONTENT (Text remains #1C1C1E & readable) */}
        {/* ========================================================= */}
        <div className="relative z-10 flex items-center justify-between gap-3 p-3.5 px-4 h-full">
          {/* Left: Task Name & Subtext */}
          <div className="flex-1 min-w-0">
            <span
              className={`text-[15px] font-semibold leading-snug block truncate ${
                isCompleted ? 'text-white line-through opacity-90' : 'text-[#1C1C1E]'
              }`}
            >
              {task.taskNameSnapshot}
            </span>

            <div className="flex items-center gap-2 text-[11px] mt-1">
              {isCompleted ? (
                <span className="text-white/90 font-medium flex items-center gap-1">
                  <Check className="w-3.5 h-3.5 stroke-[3]" />
                  承認完了・QRセル開放済み
                </span>
              ) : isVerifying ? (
                <span className="text-[#1C1C1E] font-medium flex items-center gap-1">
                  <Loader2 className="w-3 h-3 animate-spin" />
                  サーバー確認中 (約1秒)…
                </span>
              ) : isRejecting ? (
                <span className="text-[#FF3B30] font-semibold flex items-center gap-1">
                  <AlertCircle className="w-3.5 h-3.5" />
                  完了却下 (水位低下中)
                </span>
              ) : deadlineLessThan5s ? (
                <span className="text-[#FF3B30] font-medium flex items-center gap-1">
                  <Clock className="w-3 h-3" />
                  締切直前のため操作不可
                </span>
              ) : accessibleMode ? (
                <span className="text-slate-500 font-medium">タップで確認ダイアログ</span>
              ) : (
                <span
                  className={`tabular-nums font-medium ${
                    isPressingCurrentTask ? 'text-[#1C1C1E] font-bold' : 'text-[#8E8E93]'
                  }`}
                >
                  {isPressingCurrentTask
                    ? `チャージ中: ${Math.round(progress)}% (4秒長押し)`
                    : '4秒長押しでチャージ'}
                </span>
              )}
            </div>
          </div>

          {/* Right: State / Badge */}
          {isCompleted ? (
            <div className="w-8 h-8 rounded-full bg-white text-[#34C759] flex items-center justify-center shrink-0 shadow-xs">
              <Check className="w-5 h-5 stroke-[3.2]" />
            </div>
          ) : accessibleMode ? (
            <button
              onClick={() => setShowConfirmModal(true)}
              disabled={cannotPress}
              className="px-3 py-1.5 text-xs font-semibold rounded-xl bg-[#34C759] text-white hover:bg-[#28A745] active:scale-95 transition-transform shrink-0 disabled:opacity-40 shadow-xs"
            >
              完了
            </button>
          ) : (
            <div className="flex items-center shrink-0">
              {isPressingCurrentTask ? (
                <div className="px-2.5 py-1 rounded-lg bg-[#1C1C1E] text-white text-[11px] font-bold tabular-nums shadow-xs">
                  {Math.round(progress)}%
                </div>
              ) : (
                <div className="text-[10.5px] font-semibold text-slate-400 px-2 py-0.5 rounded-md bg-slate-100/80 border border-slate-200">
                  4s
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Accessibility Confirmation Modal */}
      {showConfirmModal && (
        <div className="fixed inset-0 z-50 bg-black/40 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl p-5 w-full max-w-[320px] shadow-xl text-center animate-in zoom-in-95 duration-150">
            <h3 className="text-base font-semibold text-[#1C1C1E] mb-2">タスク完了の確認</h3>
            <p className="text-xs text-slate-600 mb-5 leading-relaxed">
              「{task.taskNameSnapshot}」を完了しますか？
            </p>
            <div className="grid grid-cols-2 gap-2">
              <button
                onClick={() => setShowConfirmModal(false)}
                className="py-2.5 px-3 text-xs font-medium text-slate-700 bg-slate-100 rounded-xl hover:bg-slate-200 transition-colors"
              >
                キャンセル
              </button>
              <button
                onClick={handleAccessibleComplete}
                className="py-2.5 px-3 text-xs font-semibold text-white bg-[#34C759] rounded-xl hover:bg-[#28A745] transition-colors"
              >
                完了する (OK)
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
};
