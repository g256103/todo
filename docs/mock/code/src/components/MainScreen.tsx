import React, { useState, useEffect } from 'react';
import { Play, Clock, ChevronRight, Check, Zap, RefreshCw, AlertTriangle } from 'lucide-react';
import { Challenge, Task, Routine, ChallengeTask, ChallengeStatus } from '../types';
import { TaskBatteryItem } from './TaskBatteryItem';
import { RevealingQR } from './RevealingQR';
import { SuccessView } from './SuccessView';
import { FailedView } from './FailedView';
import { SnackbarMessage } from './Snackbar';

interface MainScreenProps {
  challenge: Challenge | null;
  tasks: Task[];
  routines: Routine[];
  onCreateChallenge: (amount: number, selectedTaskIds: string[], deadlineMinutes: number) => void;
  onStartChallenge: () => void;
  onCompleteTask: (taskId: string) => Promise<boolean>;
  onResetChallenge: () => void;
  onGoToPoints: () => void;
  isSimulatingReject: boolean;
  deadlineOverrideLessThan5s: boolean;
  accessibleMode: boolean;
  onShowSnackbar: (msg: Omit<SnackbarMessage, 'id'>) => void;
  justApprovedTaskIndex: number | null;
  onClearJustApprovedTaskIndex: () => void;
  onTransitionToSuccess: () => void;
  forcedProgress?: number | null;
  forceRejectTrigger?: number;
}

export const MainScreen: React.FC<MainScreenProps> = ({
  challenge,
  tasks,
  routines,
  onCreateChallenge,
  onStartChallenge,
  onCompleteTask,
  onResetChallenge,
  onGoToPoints,
  isSimulatingReject,
  deadlineOverrideLessThan5s,
  accessibleMode,
  onShowSnackbar,
  justApprovedTaskIndex,
  onClearJustApprovedTaskIndex,
  onTransitionToSuccess,
  forcedProgress = null,
  forceRejectTrigger = 0,
}) => {
  // Creation Flow States
  const [selectedAmount, setSelectedAmount] = useState<number>(1000);
  const [selectedTaskIds, setSelectedTaskIds] = useState<string[]>(['task-1', 'task-2', 'task-3']);
  const [deadlineMinutes, setDeadlineMinutes] = useState<number>(30);

  // Mock PayPay Modal States
  const [showPayPayModal, setShowPayPayModal] = useState(false);
  const [payPayStep, setPayPayStep] = useState<'CONFIRM' | 'PROCESSING' | 'SUCCESS'>('CONFIRM');

  // Active pressing state for exclusive long press
  const [activePressingId, setActivePressingId] = useState<string | null>(null);

  // Timers
  const [remainingDeadlineSeconds, setRemainingDeadlineSeconds] = useState<number>(1800);
  const [autoStartSeconds, setAutoStartSeconds] = useState<number>(300); // 5 min auto-start

  // Sync remaining deadline seconds when challenge updates
  useEffect(() => {
    if (!challenge) return;

    if (challenge.status === 'WAITING') {
      const calcAutoStart = () => {
        const autoTime = new Date(challenge.autoStartAt).getTime();
        const now = Date.now();
        const diffSec = Math.max(0, Math.floor((autoTime - now) / 1000));
        setAutoStartSeconds(diffSec);
        if (diffSec <= 0) {
          onStartChallenge();
        }
      };
      calcAutoStart();
      const interval = setInterval(calcAutoStart, 1000);
      return () => clearInterval(interval);
    }

    if (challenge.status === 'IN_PROGRESS') {
      const calcDeadline = () => {
        if (deadlineOverrideLessThan5s) {
          setRemainingDeadlineSeconds(4);
          return;
        }
        const deadlineTime = new Date(challenge.deadline).getTime();
        const now = Date.now();
        const diffSec = Math.max(0, Math.floor((deadlineTime - now) / 1000));
        setRemainingDeadlineSeconds(diffSec);
      };
      calcDeadline();
      const interval = setInterval(calcDeadline, 1000);
      return () => clearInterval(interval);
    }
  }, [challenge, deadlineOverrideLessThan5s, onStartChallenge]);

  // Handle Routine Click to select grouped tasks
  const handleSelectRoutine = (routine: Routine) => {
    setSelectedTaskIds(routine.taskIds);
  };

  const toggleTaskSelection = (taskId: string) => {
    setSelectedTaskIds((prev) =>
      prev.includes(taskId) ? prev.filter((id) => id !== taskId) : [...prev, taskId]
    );
  };

  // Mock PayPay Flow Handlers
  const handleOpenPayment = () => {
    if (selectedTaskIds.length === 0) {
      onShowSnackbar({ type: 'error', text: '少なくとも1つのタスクを選択してください' });
      return;
    }
    setPayPayStep('CONFIRM');
    setShowPayPayModal(true);
  };

  const handleExecutePayment = () => {
    setPayPayStep('PROCESSING');
    setTimeout(() => {
      setPayPayStep('SUCCESS');
      if (navigator.vibrate) {
        try {
          navigator.vibrate(80);
        } catch {
          // ignore
        }
      }
    }, 900);
  };

  const handleFinishPaymentAndCreate = () => {
    setShowPayPayModal(false);
    onCreateChallenge(selectedAmount, selectedTaskIds, deadlineMinutes);
  };

  // Format seconds to mm:ss
  const formatTime = (totalSec: number) => {
    const mins = Math.floor(totalSec / 60);
    const secs = totalSec % 60;
    return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
  };

  // ==========================================
  // VIEW 1: SUCCESS VIEW
  // ==========================================
  if (challenge && challenge.status === 'SUCCESS') {
    return (
      <SuccessView
        amount={challenge.amount}
        qrToken={challenge.qrToken}
        onResetToNewChallenge={onResetChallenge}
      />
    );
  }

  // ==========================================
  // VIEW 2: FAILED VIEW
  // ==========================================
  if (challenge && challenge.status === 'FAILED') {
    return (
      <FailedView
        amount={challenge.amount}
        tasks={challenge.tasks}
        onGoToPoints={onGoToPoints}
        onResetToNewChallenge={onResetChallenge}
      />
    );
  }

  // ==========================================
  // VIEW 3: WAITING FOR START
  // ==========================================
  if (challenge && challenge.status === 'WAITING') {
    return (
      <div className="min-h-full flex flex-col justify-between p-5 pb-24 text-center">
        <div className="pt-4 flex flex-col items-center">
          {/* Status Badge */}
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-amber-500/10 text-amber-700 text-xs font-semibold mb-4">
            <Clock className="w-3.5 h-3.5" />
            <span>開始待機中 (自動開始カウントダウン)</span>
          </div>

          <h2 className="text-xl font-bold text-[#1C1C1E] mb-1">決済が完了しました</h2>
          <p className="text-xs text-[#8E8E93] mb-6">
            「始める」を押すと即座にチャレンジが開始されます
          </p>

          {/* Auto Start Notice Box */}
          <div className="w-full bg-white rounded-2xl border border-black/[0.08] p-5 shadow-xs mb-4">
            <span className="text-xs text-slate-500 block mb-1">自動開始まで残り</span>
            <div className="text-4xl font-bold tracking-tight text-[#FF0033] tabular-nums my-2">
              {formatTime(autoStartSeconds)}
            </div>
            <p className="text-[11px] text-[#8E8E93]">
              ※ボタンを押さなくても5分後にサーバー時刻基準で自動開始されます
            </p>
          </div>

          {/* Challenge Summary Box */}
          <div className="w-full bg-white rounded-2xl border border-black/[0.08] p-4 text-left shadow-xs">
            <div className="flex justify-between items-center pb-2.5 border-b border-black/[0.06] mb-2.5">
              <span className="text-xs text-[#8E8E93]">コミット金額</span>
              <span className="text-base font-bold text-[#1C1C1E] tabular-nums">
                ¥{challenge.amount.toLocaleString()}
              </span>
            </div>
            <div className="flex justify-between items-center pb-2.5 border-b border-black/[0.06] mb-2.5">
              <span className="text-xs text-[#8E8E93]">対象タスク</span>
              <span className="text-xs font-medium text-[#1C1C1E]">
                {challenge.tasks.length} 件
              </span>
            </div>
            <div className="space-y-1.5 pt-1">
              {challenge.tasks.map((task, idx) => (
                <div key={task.id} className="text-xs text-slate-700 flex items-center gap-2">
                  <span className="w-4 h-4 rounded-full bg-slate-100 text-[10px] flex items-center justify-center font-mono">
                    {idx + 1}
                  </span>
                  <span className="truncate">{task.taskNameSnapshot}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Start Button */}
        <div className="pt-4">
          <button
            onClick={onStartChallenge}
            className="w-full py-3.5 px-4 rounded-xl bg-[#FF0033] text-white font-semibold text-sm hover:bg-[#E0002C] active:scale-98 transition-transform shadow-md flex items-center justify-center gap-2"
          >
            <Play className="w-4 h-4 fill-white" />
            <span>今すぐ始める</span>
          </button>
        </div>
      </div>
    );
  }

  // ==========================================
  // VIEW 4: IN_PROGRESS (CHALLENGE EXECUTION)
  // ==========================================
  if (challenge && challenge.status === 'IN_PROGRESS') {
    const isDeadlineLessThan5s =
      deadlineOverrideLessThan5s || remainingDeadlineSeconds <= 5;
    const totalTasksCount = challenge.tasks.length;
    const completedTasksCount = challenge.tasks.filter(
      (t) => t.status === 'COMPLETED'
    ).length;

    return (
      <div className="min-h-full flex flex-col p-4 pb-24">
        {/* ========================================================= */}
        {/* C. TOP LARGE REVEALING QR CODE (Single Unified QR) */}
        {/* ========================================================= */}
        <RevealingQR
          token={challenge.qrToken || 'paypay-commit-token-2026-v3'}
          tasks={challenge.tasks}
          justApprovedTaskIndex={justApprovedTaskIndex}
          onRevealFinished={onClearJustApprovedTaskIndex}
          onAllCompletedFinished={onTransitionToSuccess}
        />

        {/* Top Header Card: Deadline countdown & commit amount */}
        <div className="bg-white rounded-2xl border border-black/[0.08] p-3.5 shadow-2xs mt-3 mb-3">
          <div className="flex items-center justify-between mb-1.5">
            <div className="flex items-center gap-1.5 text-xs text-slate-500">
              <Clock className="w-3.5 h-3.5 text-[#FF0033]" />
              <span>締切まで残り</span>
            </div>
            <div className="text-[11px] font-medium text-slate-500 tabular-nums">
              進捗: {completedTasksCount}/{totalTasksCount} 完了
            </div>
          </div>

          <div className="flex items-baseline justify-between">
            <div
              className={`text-2xl font-extrabold tabular-nums tracking-tight ${
                isDeadlineLessThan5s ? 'text-[#FF3B30] animate-pulse' : 'text-[#1C1C1E]'
              }`}
            >
              {formatTime(remainingDeadlineSeconds)}
            </div>

            <div className="text-right">
              <span className="text-[10px] text-[#8E8E93] block">コミット金額</span>
              <span className="text-sm font-bold text-[#FF0033] tabular-nums">
                ¥{challenge.amount.toLocaleString()}
              </span>
            </div>
          </div>

          {/* Warning banner if deadline < 5s */}
          {isDeadlineLessThan5s && (
            <div className="mt-2.5 py-1.5 px-2.5 rounded-lg bg-[#FF3B30]/10 border border-[#FF3B30]/20 flex items-center gap-1.5 text-[11px] text-[#FF3B30] font-medium">
              <AlertTriangle className="w-3.5 h-3.5 shrink-0" />
              <span>締切まで残り5秒未満です。タスク操作は禁止されています。</span>
            </div>
          )}
        </div>

        {/* Task List Header */}
        <div className="flex items-center justify-between px-1 mb-2">
          <h2 className="text-xs font-bold text-slate-700 uppercase tracking-wider flex items-center gap-1.5">
            <Zap className="w-3.5 h-3.5 text-[#34C759]" />
            <span>対象タスク一覧</span>
          </h2>
          <span className="text-[11px] text-slate-500">
            {accessibleMode ? 'タップで完了' : '4秒長押しで緑の液体チャージ'}
          </span>
        </div>

        {/* Task Items List (Each card features 2-layer wavy liquid charge from bottom-up) */}
        <div className="space-y-2.5">
          {challenge.tasks.map((task) => (
            <TaskBatteryItem
              key={task.id}
              task={task}
              activePressingId={activePressingId}
              onPressStart={(id) => setActivePressingId(id)}
              onPressEnd={() => setActivePressingId(null)}
              onComplete={onCompleteTask}
              onServerRejectTriggered={(_, msg) =>
                onShowSnackbar({ type: 'error', text: msg })
              }
              isSimulatingReject={isSimulatingReject}
              deadlineLessThan5s={isDeadlineLessThan5s}
              accessibleMode={accessibleMode}
              forcedProgress={activePressingId === task.id ? forcedProgress : null}
              forceRejectTrigger={forceRejectTrigger}
            />
          ))}
        </div>

        {/* Guidance Footer */}
        <div className="mt-auto pt-4 text-center">
          <p className="text-[11px] text-[#8E8E93] leading-relaxed">
            {accessibleMode
              ? '支援機能モード: 「完了」ボタンを押すと確認ダイアログが表示されます'
              : '長押し中はタスク行に緑の液体が溜まります。承認されるとQRセルが現れます'}
          </p>
        </div>
      </div>
    );
  }

  // ==========================================
  // VIEW 5: CREATE CHALLENGE FLOW
  // ==========================================
  return (
    <div className="min-h-full flex flex-col justify-between p-4 pb-24">
      <div>
        {/* App Title & Value Proposition */}
        <div className="mb-4 pt-1">
          <h1 className="text-lg font-bold text-[#1C1C1E] tracking-tight flex items-center gap-2">
            <span>新しいチャレンジ</span>
            <span className="text-[10px] font-semibold text-[#FF0033] bg-[#FF0033]/10 px-2 py-0.5 rounded-full">
              PayPayコミット
            </span>
          </h1>
          <p className="text-xs text-[#8E8E93] mt-1">
            金額をコミットして集中。全タスク達成で全額返金されます。
          </p>
        </div>

        {/* Step 1: Amount Selection (100 - 5000 yen, 100 yen steps) */}
        <div className="bg-white rounded-2xl border border-black/[0.08] p-4 shadow-xs mb-3.5">
          <div className="flex items-center justify-between mb-1.5">
            <span className="text-xs font-semibold text-slate-700">コミット金額 (返金担保)</span>
            <span className="text-[11px] text-[#8E8E93]">100円単位</span>
          </div>

          <div className="text-center py-2">
            <span className="text-3xl font-extrabold text-[#1C1C1E] tabular-nums tracking-tight">
              ¥{selectedAmount.toLocaleString()}
            </span>
          </div>

          {/* Slider (100 - 5000) */}
          <input
            type="range"
            min="100"
            max="5000"
            step="100"
            value={selectedAmount}
            onChange={(e) => setSelectedAmount(Number(e.target.value))}
            className="w-full h-2 bg-slate-200 rounded-lg appearance-none cursor-pointer accent-[#FF0033] my-2"
          />

          {/* Quick Amount Chips */}
          <div className="grid grid-cols-4 gap-1.5 mt-2">
            {[500, 1000, 2000, 5000].map((amt) => (
              <button
                key={amt}
                onClick={() => setSelectedAmount(amt)}
                className={`py-1.5 text-xs font-medium rounded-lg transition-colors tabular-nums ${
                  selectedAmount === amt
                    ? 'bg-[#FF0033] text-white font-semibold'
                    : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                }`}
              >
                ¥{amt.toLocaleString()}
              </button>
            ))}
          </div>
        </div>

        {/* Step 2: Deadline Choice */}
        <div className="bg-white rounded-2xl border border-black/[0.08] p-4 shadow-xs mb-3.5">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-semibold text-slate-700">締切 (タイマー)</span>
            <span className="text-[11px] text-slate-500 tabular-nums">{deadlineMinutes} 分</span>
          </div>
          <div className="grid grid-cols-3 gap-2">
            {[15, 30, 60].map((mins) => (
              <button
                key={mins}
                onClick={() => setDeadlineMinutes(mins)}
                className={`py-1.5 text-xs font-medium rounded-lg transition-colors tabular-nums ${
                  deadlineMinutes === mins
                    ? 'bg-[#1C1C1E] text-white font-semibold'
                    : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                }`}
              >
                {mins}分後
              </button>
            ))}
          </div>
        </div>

        {/* Step 3: Routines & Task Selection */}
        <div className="bg-white rounded-2xl border border-black/[0.08] p-4 shadow-xs">
          <div className="flex items-center justify-between mb-2.5">
            <span className="text-xs font-semibold text-slate-700">対象タスクを選択</span>
            <span className="text-[11px] text-[#8E8E93]">
              {selectedTaskIds.length} 個選択中
            </span>
          </div>

          {/* Routine Quick Select */}
          {routines.length > 0 && (
            <div className="mb-3">
              <span className="text-[10.5px] text-slate-400 block mb-1.5">ルーティーンから選ぶ</span>
              <div className="flex gap-1.5 overflow-x-auto no-scrollbar pb-1">
                {routines.map((routine) => {
                  const isAllSelected = routine.taskIds.every((id) =>
                    selectedTaskIds.includes(id)
                  );
                  return (
                    <button
                      key={routine.id}
                      onClick={() => handleSelectRoutine(routine)}
                      className={`py-1.5 px-3 rounded-lg text-xs whitespace-nowrap transition-colors border ${
                        isAllSelected
                          ? 'bg-[#FF0033]/10 border-[#FF0033] text-[#FF0033] font-semibold'
                          : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
                      }`}
                    >
                      {routine.name} ({routine.taskIds.length})
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {/* Individual Tasks List */}
          <div className="space-y-1.5 max-h-[190px] overflow-y-auto no-scrollbar">
            {tasks.map((task) => {
              const isSelected = selectedTaskIds.includes(task.id);
              return (
                <div
                  key={task.id}
                  onClick={() => toggleTaskSelection(task.id)}
                  className={`flex items-center justify-between p-2.5 rounded-xl border cursor-pointer transition-all ${
                    isSelected
                      ? 'bg-red-50/50 border-[#FF0033]/40 text-[#1C1C1E]'
                      : 'bg-slate-50/80 border-slate-200/80 text-slate-600 hover:bg-slate-100'
                  }`}
                >
                  <span className="text-xs font-medium truncate max-w-[220px]">
                    {task.name}
                  </span>
                  <div
                    className={`w-5 h-5 rounded-md flex items-center justify-center transition-colors ${
                      isSelected ? 'bg-[#FF0033] text-white' : 'border border-slate-300'
                    }`}
                  >
                    {isSelected && <Check className="w-3.5 h-3.5 stroke-[3]" />}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Primary CTA: Open Mock PayPay Payment */}
      <div className="pt-4">
        <button
          onClick={handleOpenPayment}
          disabled={selectedTaskIds.length === 0}
          className="w-full py-3.5 px-4 rounded-xl bg-[#FF0033] text-white font-semibold text-sm hover:bg-[#E0002C] active:scale-98 transition-transform shadow-md flex items-center justify-center gap-2 disabled:opacity-40"
        >
          <span>PayPay決済に進む (¥{selectedAmount.toLocaleString()})</span>
          <ChevronRight className="w-4 h-4" />
        </button>
      </div>

      {/* ==================================================== */}
      {/* MOCK PAYPAY PAYMENT MODAL SHEET (PayPay-style flow) */}
      {/* ==================================================== */}
      {showPayPayModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-end justify-center">
          <div className="w-full max-w-[393px] bg-white rounded-t-3xl p-5 shadow-2xl animate-in slide-in-from-bottom duration-200">
            {/* Grab Handle */}
            <div className="w-10 h-1 bg-slate-300 rounded-full mx-auto mb-4" />

            {payPayStep === 'CONFIRM' && (
              <div>
                <div className="flex items-center justify-between pb-3 border-b border-slate-100 mb-4">
                  <div className="flex items-center gap-2">
                    <div className="w-6 h-6 rounded-md bg-[#FF0033] flex items-center justify-center text-white font-bold text-xs">
                      P
                    </div>
                    <span className="text-xs font-bold text-[#1C1C1E]">
                      PayPay風モック決済
                    </span>
                  </div>
                  <button
                    onClick={() => setShowPayPayModal(false)}
                    className="text-xs text-slate-400 hover:text-slate-600"
                  >
                    キャンセル
                  </button>
                </div>

                <div className="text-center my-4">
                  <span className="text-xs text-slate-500 block mb-1">お支払い金額</span>
                  <div className="text-3xl font-extrabold text-[#1C1C1E] tabular-nums">
                    ¥{selectedAmount.toLocaleString()}
                  </div>
                </div>

                <div className="bg-[#F5F5F7] rounded-xl p-3.5 mb-5 space-y-2 text-xs">
                  <div className="flex justify-between">
                    <span className="text-slate-500">お支払い先</span>
                    <span className="font-semibold text-slate-800">
                      ToDoコミット・デポジット
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500">お支払い方法</span>
                    <span className="font-semibold text-slate-800">
                      PayPay残高 (残高: ¥12,450)
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500">返金条件</span>
                    <span className="text-[#34C759] font-medium">
                      期限内タスク達成で全額返金
                    </span>
                  </div>
                </div>

                <button
                  onClick={handleExecutePayment}
                  className="w-full py-3.5 px-4 rounded-xl bg-[#FF0033] text-white font-bold text-sm hover:bg-[#E0002C] active:scale-98 transition-transform shadow-md flex items-center justify-center gap-2"
                >
                  <span>支払う (¥{selectedAmount.toLocaleString()})</span>
                </button>
              </div>
            )}

            {payPayStep === 'PROCESSING' && (
              <div className="py-12 flex flex-col items-center justify-center text-center">
                <RefreshCw className="w-10 h-10 text-[#FF0033] animate-spin mb-4" />
                <h3 className="text-base font-bold text-[#1C1C1E] mb-1">決済処理中…</h3>
                <p className="text-xs text-slate-400">
                  モックPayPayサーバーで認証中
                </p>
              </div>
            )}

            {payPayStep === 'SUCCESS' && (
              <div className="py-6 flex flex-col items-center justify-center text-center">
                <div className="w-14 h-14 rounded-full bg-[#34C759]/15 text-[#34C759] flex items-center justify-center mb-3">
                  <Check className="w-8 h-8 stroke-[3]" />
                </div>
                <h3 className="text-lg font-bold text-[#1C1C1E] mb-1">
                  支払い完了 (モック)
                </h3>
                <p className="text-xs text-slate-500 mb-6">
                  ¥{selectedAmount.toLocaleString()} のデポジットを完了しました
                </p>

                <button
                  onClick={handleFinishPaymentAndCreate}
                  className="w-full py-3.5 px-4 rounded-xl bg-[#1C1C1E] text-white font-bold text-sm hover:bg-black active:scale-98 transition-transform shadow-md"
                >
                  チャレンジ画面へ進む
                </button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
