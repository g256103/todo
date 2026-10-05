/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useEffect, useCallback, useId } from 'react';
import { TabType, Challenge, Task, Routine, HistoryItem, PointTransaction, UserProfile, ChallengeStatus } from './types';
import {
  INITIAL_USER,
  INITIAL_TASKS,
  INITIAL_ROUTINES,
  INITIAL_HISTORY,
  INITIAL_POINT_TRANSACTIONS,
} from './mockData';
import { PhoneFrame } from './components/PhoneFrame';
import { BottomNav } from './components/BottomNav';
import { MainScreen } from './components/MainScreen';
import { PointsScreen } from './components/PointsScreen';
import { HistoryScreen } from './components/HistoryScreen';
import { EditScreen } from './components/EditScreen';
import { SettingsScreen } from './components/SettingsScreen';
import { DevMenu } from './components/DevMenu';
import { Snackbar, SnackbarMessage } from './components/Snackbar';

export default function App() {
  // Navigation
  const [currentTab, setCurrentTab] = useState<TabType>('main');

  // Core Data in Memory (useState only, no localStorage)
  const [user, setUser] = useState<UserProfile>(INITIAL_USER);
  const [tasks, setTasks] = useState<Task[]>(INITIAL_TASKS);
  const [routines, setRoutines] = useState<Routine[]>(INITIAL_ROUTINES);
  const [history, setHistory] = useState<HistoryItem[]>(INITIAL_HISTORY);
  const [points, setPoints] = useState<number>(1200);
  const [pointTransactions, setPointTransactions] = useState<PointTransaction[]>(INITIAL_POINT_TRANSACTIONS);

  // Active Challenge (Initial: ready for creation, or pre-configured in progress for immediate review)
  const [challenge, setChallenge] = useState<Challenge | null>(() => {
    // Provide an initial IN_PROGRESS challenge with 3 tasks so reviewer can immediately test the 4-second hold
    const now = new Date();
    const deadline = new Date(now.getTime() + 25 * 60 * 1000); // 25 min from now
    return {
      id: 'ch-init-1',
      paymentId: 'pay-init-1',
      amount: 1000,
      status: 'IN_PROGRESS',
      createdAt: now.toISOString(),
      autoStartAt: now.toISOString(),
      startedAt: now.toISOString(),
      deadline: deadline.toISOString(),
      tasks: [
        {
          id: 'ct-1',
          taskId: 'task-1',
          taskNameSnapshot: '英単語 30語暗記',
          status: 'INCOMPLETE',
        },
        {
          id: 'ct-2',
          taskId: 'task-2',
          taskNameSnapshot: 'ストレッチ & 筋トレ 15分',
          status: 'INCOMPLETE',
        },
        {
          id: 'ct-3',
          taskId: 'task-3',
          taskNameSnapshot: '技術書の読書 20ページ',
          status: 'INCOMPLETE',
        },
      ],
      qrToken: `paypay-commit-${Math.random().toString(36).substring(2, 9)}`,
      qrStatus: 'AVAILABLE',
    };
  });

  // Developer Simulation States
  const [isSimulatingReject, setIsSimulatingReject] = useState<boolean>(false);
  const [deadlineOverrideLessThan5s, setDeadlineOverrideLessThan5s] = useState<boolean>(false);
  const [isCashoutEligibleForce, setIsCashoutEligibleForce] = useState<boolean>(false);
  const [justApprovedTaskIndex, setJustApprovedTaskIndex] = useState<number | null>(null);
  const [forcedProgress, setForcedProgress] = useState<number | null>(null);
  const [forceRejectTrigger, setForceRejectTrigger] = useState<number>(0);

  // Toast / Snackbar
  const [snackbar, setSnackbar] = useState<SnackbarMessage | null>(null);

  const showSnackbar = useCallback((msg: Omit<SnackbarMessage, 'id'>) => {
    const id = Math.random().toString(36).substring(2, 9);
    setSnackbar({ ...msg, id });
    setTimeout(() => {
      setSnackbar((prev) => (prev?.id === id ? null : prev));
    }, 3500);
  }, []);

  // Challenge Lifecycle: Create Challenge
  const handleCreateChallenge = (amount: number, selectedTaskIds: string[], deadlineMinutes: number) => {
    const now = new Date();
    const autoStartTime = new Date(now.getTime() + 5 * 60 * 1000); // 5 min auto-start
    const deadlineTime = new Date(now.getTime() + (deadlineMinutes + 5) * 60 * 1000);

    const challengeTasks = selectedTaskIds.map((tid, idx) => {
      const original = tasks.find((t) => t.id === tid);
      return {
        id: `ct-${Date.now()}-${idx}`,
        taskId: tid,
        taskNameSnapshot: original ? original.name : `タスク ${idx + 1}`,
        status: 'INCOMPLETE' as const,
      };
    });

    const newChallenge: Challenge = {
      id: `ch-${Date.now()}`,
      paymentId: `pay-${Date.now()}`,
      amount,
      status: 'WAITING',
      createdAt: now.toISOString(),
      autoStartAt: autoStartTime.toISOString(),
      deadline: deadlineTime.toISOString(),
      tasks: challengeTasks,
      qrToken: `paypay-commit-${Math.random().toString(36).substring(2, 9)}`,
      qrStatus: 'AVAILABLE',
    };

    setChallenge(newChallenge);
    setDeadlineOverrideLessThan5s(false);
    showSnackbar({
      type: 'success',
      text: `¥${amount.toLocaleString()} のコミットを完了しました (5分後自動開始)`,
    });
  };

  // Start Challenge Manually
  const handleStartChallenge = () => {
    if (!challenge) return;
    setChallenge((prev) => (prev ? { ...prev, status: 'IN_PROGRESS', startedAt: new Date().toISOString() } : null));
    showSnackbar({ type: 'info', text: 'チャレンジが開始されました！' });
  };

  // Task Completion Handler
  const handleCompleteTask = async (taskId: string): Promise<boolean> => {
    if (!challenge || challenge.status !== 'IN_PROGRESS') return false;

    // Check if simulate reject is ON
    if (isSimulatingReject) {
      showSnackbar({
        type: 'error',
        text: 'サーバー検証エラー: 締切超過または判定不能により完了が拒否されました',
      });
      return false;
    }

    const taskIndex = challenge.tasks.findIndex((t) => t.id === taskId);
    if (taskIndex === -1) return false;

    // Update the challenge_tasks list
    setChallenge((prev) => {
      if (!prev) return null;
      const updatedTasks = prev.tasks.map((t) =>
        t.id === taskId
          ? { ...t, status: 'COMPLETED' as const, completedAt: new Date().toISOString() }
          : t
      );

      return {
        ...prev,
        tasks: updatedTasks,
      };
    });

    // Trigger QR cell reveal for this approved task
    setJustApprovedTaskIndex(taskIndex);

    return true;
  };

  // Called when all cells of the last task have revealed and QR flash completes
  const handleTransitionToSuccess = () => {
    if (!challenge) return;

    const historyRecord: HistoryItem = {
      id: `hist-${Date.now()}`,
      date: new Date().toISOString().replace('T', ' ').substring(0, 16),
      amount: challenge.amount,
      status: 'SUCCESS',
      refundAmount: challenge.amount,
      tasks: challenge.tasks.map((t) => ({
        name: t.taskNameSnapshot,
        completed: true,
      })),
    };
    setHistory((h) => [historyRecord, ...h]);
    setUser((u) => ({
      ...u,
      successCount: u.successCount + 1,
      streakCount: u.streakCount + 1,
    }));

    setChallenge((prev) =>
      prev ? { ...prev, status: 'SUCCESS', finishedAt: new Date().toISOString() } : null
    );
    setJustApprovedTaskIndex(null);
  };

  // Dev Menu: Complete Next Task immediately (to test QR reveal animation)
  const handleCompleteNextTask = () => {
    if (!challenge || challenge.status !== 'IN_PROGRESS') {
      showSnackbar({ type: 'info', text: '現在進行中のチャレンジがありません' });
      return;
    }
    const nextIncomplete = challenge.tasks.find((t) => t.status === 'INCOMPLETE');
    if (nextIncomplete) {
      handleCompleteTask(nextIncomplete.id);
    } else {
      showSnackbar({ type: 'info', text: '全タスクが既に完了しています' });
    }
  };

  // Dev Menu: Force progress change (0%, 50%, 100%)
  const handleSetForcedProgress = (val: number | null) => {
    setForcedProgress(val);
    if (val !== null) {
      showSnackbar({ type: 'info', text: `長押し液体の水位を強制設定: ${val}%` });
    } else {
      showSnackbar({ type: 'info', text: '強制水位設定を解除しました' });
    }
  };

  // Dev Menu: Play server reject animation
  const handleTriggerRejectAnimation = () => {
    setForceRejectTrigger((prev) => prev + 1);
    showSnackbar({
      type: 'error',
      text: 'サーバー拒否アニメーションを再生中（液体が下降して0に戻ります）',
    });
  };

  // Reset / Clear Challenge back to creation
  const handleResetChallenge = () => {
    setChallenge(null);
    setDeadlineOverrideLessThan5s(false);
    setJustApprovedTaskIndex(null);
    setForcedProgress(null);
  };

  // Handle Point Exchange
  const handleExchange = (itemId: string, pointsNeeded: number, itemName: string) => {
    if (points < pointsNeeded) {
      showSnackbar({ type: 'error', text: 'ポイント残高が不足しています' });
      return;
    }
    setPoints((p) => p - pointsNeeded);
    const newTx: PointTransaction = {
      id: `pt-${Date.now()}`,
      title: `商品交換: ${itemName}`,
      amount: -pointsNeeded,
      type: 'EXCHANGE',
      date: new Date().toISOString().substring(0, 10),
      expiresAt: '-',
    };
    setPointTransactions((txs) => [newTx, ...txs]);
    showSnackbar({ type: 'success', text: `「${itemName}」と交換しました！` });
  };

  // Handle Point Cashout
  const handleCashout = (pointsAmount: number) => {
    setPoints((p) => p - pointsAmount);
    const newTx: PointTransaction = {
      id: `pt-${Date.now()}`,
      title: 'ポイント現金化申請 (手数料10%控除)',
      amount: -pointsAmount,
      type: 'CASHOUT',
      date: new Date().toISOString().substring(0, 10),
      expiresAt: '-',
    };
    setPointTransactions((txs) => [newTx, ...txs]);
    showSnackbar({
      type: 'success',
      text: `¥${(pointsAmount * 0.9).toLocaleString()} の振込申請を完了しました`,
    });
  };

  // Task & Routine CRUD Handlers
  const handleAddTask = (name: string, category: string) => {
    const newTask: Task = {
      id: `task-${Date.now()}`,
      name,
      category,
      createdAt: new Date().toISOString().substring(0, 10),
    };
    setTasks((prev) => [newTask, ...prev]);
    showSnackbar({ type: 'success', text: `タスク「${name}」を追加しました` });
  };

  const handleEditTask = (id: string, name: string) => {
    setTasks((prev) => prev.map((t) => (t.id === id ? { ...t, name } : t)));
    showSnackbar({ type: 'info', text: 'タスク名を変更しました' });
  };

  const handleDeleteTask = (id: string) => {
    const taskToDelete = tasks.find((t) => t.id === id);
    setTasks((prev) => prev.filter((t) => t.id !== id));
    // Also remove from routines
    setRoutines((prev) =>
      prev.map((r) => ({ ...r, taskIds: r.taskIds.filter((tid) => tid !== id) }))
    );
    showSnackbar({ type: 'info', text: `タスク「${taskToDelete?.name || ''}」を削除しました` });
  };

  const handleAddRoutine = (name: string, taskIds: string[]) => {
    const newRoutine: Routine = {
      id: `routine-${Date.now()}`,
      name,
      taskIds,
      createdAt: new Date().toISOString().substring(0, 10),
    };
    setRoutines((prev) => [newRoutine, ...prev]);
    showSnackbar({ type: 'success', text: `ルーティーン「${name}」を登録しました` });
  };

  const handleDeleteRoutine = (id: string) => {
    const routineToDelete = routines.find((r) => r.id === id);
    setRoutines((prev) => prev.filter((r) => r.id !== id));
    showSnackbar({
      type: 'info',
      text: `ルーティーン「${routineToDelete?.name || ''}」を削除しました`,
    });
  };

  // Settings Handlers
  const handleToggleAccessibleMode = (enabled: boolean) => {
    setUser((u) => ({ ...u, accessibleMode: enabled }));
    showSnackbar({
      type: 'info',
      text: enabled ? '支援機能代替モード (ダイアログ完了) を有効にしました' : '4秒長押しモードに戻しました',
    });
  };

  const handleUpdateUserName = (name: string) => {
    setUser((u) => ({ ...u, name }));
    showSnackbar({ type: 'success', text: 'ユーザー名を更新しました' });
  };

  // Developer Controls Handlers
  const handleForceStatus = (status: ChallengeStatus | 'NONE') => {
    if (status === 'NONE') {
      setChallenge(null);
      setCurrentTab('main');
      return;
    }

    const now = new Date();
    const sampleChallenge: Challenge = {
      id: `ch-dev-${Date.now()}`,
      paymentId: `pay-dev-${Date.now()}`,
      amount: 1500,
      status: status,
      createdAt: now.toISOString(),
      autoStartAt: new Date(now.getTime() + 4 * 60 * 1000).toISOString(),
      deadline: new Date(now.getTime() + 20 * 60 * 1000).toISOString(),
      tasks: [
        {
          id: 'ct-dev-1',
          taskId: 'task-1',
          taskNameSnapshot: '英単語 30語暗記',
          status: status === 'SUCCESS' ? 'COMPLETED' : 'INCOMPLETE',
        },
        {
          id: 'ct-dev-2',
          taskId: 'task-2',
          taskNameSnapshot: 'ストレッチ & 筋トレ 15分',
          status: status === 'SUCCESS' ? 'COMPLETED' : 'INCOMPLETE',
        },
      ],
      qrToken: `paypay-commit-${Math.random().toString(36).substring(2, 9)}`,
      qrStatus: 'AVAILABLE',
    };

    setChallenge(sampleChallenge);
    setCurrentTab('main');

    if (status === 'FAILED') {
      // Award educational points
      setPoints((p) => p + 1500);
      setPointTransactions((txs) => [
        {
          id: `pt-${Date.now()}`,
          title: '未完了チャレンジ補償 (デモ強制)',
          amount: 1500,
          type: 'AWARD_FAILED_CHALLENGE',
          date: new Date().toISOString().substring(0, 10),
          expiresAt: '2027-01-04',
        },
        ...txs,
      ]);
    }

    showSnackbar({ type: 'info', text: `状態を [${status}] に強制変更しました` });
  };

  const handleToggleSimulateReject = () => {
    setIsSimulatingReject((prev) => {
      const next = !prev;
      showSnackbar({
        type: next ? 'error' : 'info',
        text: next ? 'サーバー完了拒否シミュレーション: ON' : 'サーバー完了拒否シミュレーション: OFF',
      });
      return next;
    });
  };

  const handleSetDeadlineLessThan5s = () => {
    setDeadlineOverrideLessThan5s(true);
    showSnackbar({
      type: 'error',
      text: '締切を残り4秒に設定しました (5秒未満のため長押し不可)',
    });
  };

  const handleFastForwardAutoStart = () => {
    if (challenge && challenge.status === 'WAITING') {
      handleStartChallenge();
    } else {
      showSnackbar({ type: 'info', text: '待機中状態ではありません' });
    }
  };

  const handleToggleCashoutEligible = () => {
    setIsCashoutEligibleForce((prev) => {
      const next = !prev;
      setUser((u) => ({
        ...u,
        successCount: next ? 7 : 4,
        streakCount: next ? 7 : 3,
      }));
      showSnackbar({
        type: 'info',
        text: next ? '現金化条件を [達成 (7回/7日)] に設定' : '現金化条件を [未達 (4回/3日)] に設定',
      });
      return next;
    });
  };

  const handleResetAllData = () => {
    setUser(INITIAL_USER);
    setTasks(INITIAL_TASKS);
    setRoutines(INITIAL_ROUTINES);
    setHistory(INITIAL_HISTORY);
    setPoints(1200);
    setPointTransactions(INITIAL_POINT_TRANSACTIONS);
    setIsSimulatingReject(false);
    setDeadlineOverrideLessThan5s(false);
    setIsCashoutEligibleForce(false);
    setChallenge(null);
    setCurrentTab('main');
    showSnackbar({ type: 'info', text: 'すべてのデータを初期モック状態にリセットしました' });
  };

  return (
    <PhoneFrame
      devMenu={
        <DevMenu
          currentStatus={challenge ? challenge.status : 'NONE'}
          onForceStatus={handleForceStatus}
          isSimulatingReject={isSimulatingReject}
          onToggleSimulateReject={handleToggleSimulateReject}
          onSetDeadlineLessThan5s={handleSetDeadlineLessThan5s}
          onFastForwardAutoStart={handleFastForwardAutoStart}
          onToggleCashoutEligible={handleToggleCashoutEligible}
          isCashoutEligible={user.successCount >= 7 && user.streakCount >= 7}
          onResetAllData={handleResetAllData}
          onCompleteNextTask={handleCompleteNextTask}
          onSetForcedProgress={handleSetForcedProgress}
          forcedProgress={forcedProgress}
          onTriggerRejectAnimation={handleTriggerRejectAnimation}
        />
      }
    >
      {/* Toast Snackbar */}
      <Snackbar message={snackbar} onClose={() => setSnackbar(null)} />

      {/* Screen Content by Tab */}
      <div className="flex-1 flex flex-col relative overflow-y-auto no-scrollbar">
        {currentTab === 'main' && (
          <MainScreen
            challenge={challenge}
            tasks={tasks}
            routines={routines}
            onCreateChallenge={handleCreateChallenge}
            onStartChallenge={handleStartChallenge}
            onCompleteTask={handleCompleteTask}
            onResetChallenge={handleResetChallenge}
            onGoToPoints={() => setCurrentTab('points')}
            isSimulatingReject={isSimulatingReject}
            deadlineOverrideLessThan5s={deadlineOverrideLessThan5s}
            accessibleMode={user.accessibleMode}
            onShowSnackbar={showSnackbar}
            justApprovedTaskIndex={justApprovedTaskIndex}
            onClearJustApprovedTaskIndex={() => setJustApprovedTaskIndex(null)}
            onTransitionToSuccess={handleTransitionToSuccess}
            forcedProgress={forcedProgress}
            forceRejectTrigger={forceRejectTrigger}
          />
        )}

        {currentTab === 'points' && (
          <PointsScreen
            points={points}
            successCount={user.successCount}
            streakDays={user.streakCount}
            transactions={pointTransactions}
            onExchange={handleExchange}
            onCashout={handleCashout}
          />
        )}

        {currentTab === 'history' && <HistoryScreen history={history} />}

        {currentTab === 'edit' && (
          <EditScreen
            tasks={tasks}
            routines={routines}
            onAddTask={handleAddTask}
            onEditTask={handleEditTask}
            onDeleteTask={handleDeleteTask}
            onAddRoutine={handleAddRoutine}
            onDeleteRoutine={handleDeleteRoutine}
          />
        )}

        {currentTab === 'settings' && (
          <SettingsScreen
            user={user}
            onToggleAccessibleMode={handleToggleAccessibleMode}
            onUpdateUserName={handleUpdateUserName}
          />
        )}
      </div>

      {/* Glassmorphic Bottom Navigation */}
      <BottomNav currentTab={currentTab} onTabChange={(tab) => setCurrentTab(tab)} />
    </PhoneFrame>
  );
}
