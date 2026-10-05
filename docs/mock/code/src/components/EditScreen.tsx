import React, { useState, useRef } from 'react';
import { Task, Routine } from '../types';
import { Plus, Trash2, Edit2, BookmarkPlus, Layers, Check, X, Info } from 'lucide-react';

interface EditScreenProps {
  tasks: Task[];
  routines: Routine[];
  onAddTask: (name: string, category: string) => void;
  onEditTask: (id: string, name: string) => void;
  onDeleteTask: (id: string) => void;
  onAddRoutine: (name: string, taskIds: string[]) => void;
  onDeleteRoutine: (id: string) => void;
}

export const EditScreen: React.FC<EditScreenProps> = ({
  tasks,
  routines,
  onAddTask,
  onEditTask,
  onDeleteTask,
  onAddRoutine,
  onDeleteRoutine,
}) => {
  const [activeTab, setActiveTab] = useState<'tasks' | 'routines'>('tasks');

  // Swipe offset state for tasks: map taskId -> offset (-100 to 100)
  const [swipedTaskId, setSwipedTaskId] = useState<string | null>(null);
  const [swipeOffset, setSwipeOffset] = useState<number>(0);
  const touchStartRef = useRef<{ x: number; y: number; id: string } | null>(null);

  // Modals
  const [showAddTaskModal, setShowAddTaskModal] = useState(false);
  const [newTaskName, setNewTaskName] = useState('');
  const [newTaskCategory, setNewTaskCategory] = useState('学習');

  const [editingTask, setEditingTask] = useState<Task | null>(null);
  const [editTaskName, setEditTaskName] = useState('');

  // Routine Preview Modal (triggered by long press on routine)
  const [previewRoutine, setPreviewRoutine] = useState<Routine | null>(null);
  const routinePressTimerRef = useRef<NodeJS.Timeout | null>(null);
  const [pressingRoutineId, setPressingRoutineId] = useState<string | null>(null);

  // Add Routine Modal
  const [showAddRoutineModal, setShowAddRoutineModal] = useState(false);
  const [newRoutineName, setNewRoutineName] = useState('');
  const [selectedTaskIdsForRoutine, setSelectedTaskIdsForRoutine] = useState<string[]>([]);

  // Touch handlers for swipe
  const handleTouchStart = (e: React.TouchEvent | React.MouseEvent, taskId: string) => {
    const clientX = 'touches' in e ? e.touches[0].clientX : e.clientX;
    const clientY = 'touches' in e ? e.touches[0].clientY : e.clientY;
    touchStartRef.current = { x: clientX, y: clientY, id: taskId };
    setSwipedTaskId(taskId);
  };

  const handleTouchMove = (e: React.TouchEvent | React.MouseEvent) => {
    if (!touchStartRef.current) return;
    const clientX = 'touches' in e ? e.touches[0].clientX : e.clientX;
    const deltaX = clientX - touchStartRef.current.x;

    // Constrain delta between -90 and 90 px
    const constrained = Math.max(-100, Math.min(100, deltaX));
    setSwipeOffset(constrained);
  };

  const handleTouchEnd = () => {
    if (Math.abs(swipeOffset) < 35) {
      setSwipeOffset(0);
      setSwipedTaskId(null);
    } else {
      // Snap open either left (-80) or right (+80)
      setSwipeOffset(swipeOffset > 0 ? 80 : -80);
    }
    touchStartRef.current = null;
  };

  // Routine long press handler
  const handleRoutinePointerDown = (routine: Routine) => {
    setPressingRoutineId(routine.id);
    routinePressTimerRef.current = setTimeout(() => {
      setPreviewRoutine(routine);
      setPressingRoutineId(null);
      if (navigator.vibrate) {
        try {
          navigator.vibrate(50);
        } catch {
          // ignore
        }
      }
    }, 450); // 450ms long press
  };

  const handleRoutinePointerUp = () => {
    if (routinePressTimerRef.current) {
      clearTimeout(routinePressTimerRef.current);
      routinePressTimerRef.current = null;
    }
    setPressingRoutineId(null);
  };

  return (
    <div className="min-h-full flex flex-col p-4 pb-24">
      {/* Title & Segments */}
      <div className="flex items-center justify-between mb-3 pt-1">
        <div>
          <h1 className="text-lg font-bold text-[#1C1C1E] tracking-tight">タスク & ルーティーン</h1>
          <p className="text-xs text-[#8E8E93]">スワイプ操作または長押しで管理</p>
        </div>

        <button
          onClick={() =>
            activeTab === 'tasks' ? setShowAddTaskModal(true) : setShowAddRoutineModal(true)
          }
          className="w-9 h-9 rounded-xl bg-[#FF0033] text-white flex items-center justify-center hover:bg-[#E0002C] active:scale-95 shadow-xs"
        >
          <Plus className="w-5 h-5 stroke-[2.5]" />
        </button>
      </div>

      {/* Segmented Switcher */}
      <div className="flex p-1 bg-slate-200/80 rounded-xl mb-3.5">
        <button
          onClick={() => {
            setActiveTab('tasks');
            setSwipeOffset(0);
          }}
          className={`flex-1 py-1.5 text-xs font-semibold rounded-lg transition-all ${
            activeTab === 'tasks'
              ? 'bg-white text-[#1C1C1E] shadow-xs'
              : 'text-slate-600 hover:text-slate-900'
          }`}
        >
          単体タスク ({tasks.length})
        </button>
        <button
          onClick={() => {
            setActiveTab('routines');
            setSwipeOffset(0);
          }}
          className={`flex-1 py-1.5 text-xs font-semibold rounded-lg transition-all ${
            activeTab === 'routines'
              ? 'bg-white text-[#1C1C1E] shadow-xs'
              : 'text-slate-600 hover:text-slate-900'
          }`}
        >
          ルーティーン ({routines.length})
        </button>
      </div>

      {/* Gesture Instruction Notice */}
      <div className="mb-3 px-3 py-2 rounded-xl bg-white/70 border border-black/[0.06] text-[11px] text-slate-500 flex items-center gap-2">
        <Info className="w-3.5 h-3.5 text-[#FF0033] shrink-0" />
        {activeTab === 'tasks' ? (
          <span>左スワイプで編集・削除、右スワイプでルーティーン登録</span>
        ) : (
          <span>ルーティーンを長押しすると、含まれるタスクを確認できます</span>
        )}
      </div>

      {/* VIEW: TASKS WITH SWIPE */}
      {activeTab === 'tasks' && (
        <div className="space-y-2">
          {tasks.map((task) => {
            const isTarget = swipedTaskId === task.id;
            const currentOffset = isTarget ? swipeOffset : 0;

            return (
              <div
                key={task.id}
                className="relative overflow-hidden rounded-2xl bg-white border border-black/[0.08] shadow-xs select-none"
              >
                {/* Background Action Underlays */}
                {/* Left reveal on right-swipe: "ルーティーン登録" */}
                <div className="absolute inset-y-0 left-0 w-24 bg-[#FF0033] text-white flex items-center justify-center gap-1 text-xs font-semibold">
                  <BookmarkPlus className="w-4 h-4" />
                  <span>登録</span>
                </div>

                {/* Right reveal on left-swipe: "編集 & 削除" */}
                <div className="absolute inset-y-0 right-0 w-28 bg-slate-900 text-white flex items-center justify-end px-2 gap-1">
                  <button
                    onClick={() => {
                      setEditingTask(task);
                      setEditTaskName(task.name);
                    }}
                    className="p-2 rounded-lg bg-slate-800 text-slate-200 hover:text-white"
                  >
                    <Edit2 className="w-3.5 h-3.5" />
                  </button>
                  <button
                    onClick={() => onDeleteTask(task.id)}
                    className="p-2 rounded-lg bg-[#FF3B30] text-white"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>

                {/* Foreground Task Card */}
                <div
                  onTouchStart={(e) => handleTouchStart(e, task.id)}
                  onTouchMove={handleTouchMove}
                  onTouchEnd={handleTouchEnd}
                  onMouseDown={(e) => handleTouchStart(e, task.id)}
                  onMouseMove={(e) => isTarget && handleTouchMove(e)}
                  onMouseUp={handleTouchEnd}
                  style={{ transform: `translateX(${currentOffset}px)` }}
                  className="relative z-10 bg-white p-3.5 flex items-center justify-between transition-transform duration-100 ease-out cursor-grab active:cursor-grabbing"
                >
                  <div className="flex-1 min-w-0 pr-2">
                    <span className="text-xs font-semibold text-[#1C1C1E] block truncate">
                      {task.name}
                    </span>
                    <span className="text-[10.5px] text-[#8E8E93]">
                      {task.category || '一般'}
                    </span>
                  </div>

                  {/* Desktop fallback action icons if not swiping */}
                  <div className="flex items-center gap-1 opacity-70">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        setEditingTask(task);
                        setEditTaskName(task.name);
                      }}
                      className="p-1.5 text-slate-400 hover:text-slate-800"
                    >
                      <Edit2 className="w-3.5 h-3.5" />
                    </button>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        onDeleteTask(task.id);
                      }}
                      className="p-1.5 text-slate-400 hover:text-[#FF3B30]"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* VIEW: ROUTINES WITH LONG PRESS */}
      {activeTab === 'routines' && (
        <div className="space-y-2">
          {routines.map((routine) => {
            const isPressing = pressingRoutineId === routine.id;
            return (
              <div
                key={routine.id}
                onPointerDown={() => handleRoutinePointerDown(routine)}
                onPointerUp={handleRoutinePointerUp}
                onPointerCancel={handleRoutinePointerUp}
                onClick={() => setPreviewRoutine(routine)}
                className={`bg-white rounded-2xl border border-black/[0.08] p-3.5 shadow-xs transition-all cursor-pointer select-none touch-none ${
                  isPressing
                    ? 'scale-[0.98] border-[#FF0033]/60 bg-red-50/20'
                    : 'hover:border-black/20'
                }`}
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 rounded-xl bg-slate-100 flex items-center justify-center text-slate-700">
                      <Layers className="w-4 h-4" />
                    </div>
                    <div>
                      <span className="text-xs font-bold text-[#1C1C1E] block">
                        {routine.name}
                      </span>
                      <span className="text-[11px] text-[#8E8E93]">
                        {routine.taskIds.length} 個のタスクが含まれています
                      </span>
                    </div>
                  </div>

                  <div className="flex items-center gap-2">
                    <span className="text-[10px] text-slate-400">長押しで確認</span>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        onDeleteRoutine(routine.id);
                      }}
                      className="p-1.5 text-slate-400 hover:text-[#FF3B30]"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Routine Detail Modal (Long press preview) */}
      {previewRoutine && (
        <div className="fixed inset-0 z-50 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl p-5 w-full max-w-[340px] shadow-2xl">
            <div className="flex items-center justify-between pb-3 border-b border-black/[0.06] mb-3">
              <div>
                <span className="text-[10px] font-bold text-[#FF0033] uppercase tracking-wider block">
                  ルーティーン内容確認
                </span>
                <h3 className="text-sm font-bold text-[#1C1C1E]">
                  {previewRoutine.name}
                </h3>
              </div>
              <button
                onClick={() => setPreviewRoutine(null)}
                className="p-1 rounded-full text-slate-400 hover:bg-slate-100"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="space-y-1.5 max-h-[220px] overflow-y-auto no-scrollbar mb-4">
              {previewRoutine.taskIds.map((tid, idx) => {
                const foundTask = tasks.find((t) => t.id === tid);
                return (
                  <div
                    key={tid}
                    className="p-2.5 rounded-xl bg-slate-50 border border-slate-200/60 flex items-center gap-2 text-xs"
                  >
                    <span className="w-4 h-4 rounded-full bg-slate-200 text-[10px] font-mono flex items-center justify-center shrink-0">
                      {idx + 1}
                    </span>
                    <span className="text-slate-800 font-medium truncate">
                      {foundTask ? foundTask.name : '削除されたタスク'}
                    </span>
                  </div>
                );
              })}
            </div>

            <button
              onClick={() => setPreviewRoutine(null)}
              className="w-full py-2.5 rounded-xl bg-[#1C1C1E] text-white text-xs font-semibold hover:bg-black active:scale-98 transition-transform"
            >
              閉じる
            </button>
          </div>
        </div>
      )}

      {/* Add Task Modal */}
      {showAddTaskModal && (
        <div className="fixed inset-0 z-50 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl p-5 w-full max-w-[320px] shadow-2xl">
            <h3 className="text-sm font-bold text-[#1C1C1E] mb-3">新しいタスクを追加</h3>
            <div className="space-y-3 mb-4">
              <div>
                <label className="text-[11px] text-slate-500 block mb-1">タスク名</label>
                <input
                  type="text"
                  placeholder="例: ストレッチ 15分"
                  value={newTaskName}
                  onChange={(e) => setNewTaskName(e.target.value)}
                  className="w-full p-2.5 text-xs border border-slate-200 rounded-xl focus:border-[#FF0033] outline-none"
                />
              </div>
              <div>
                <label className="text-[11px] text-slate-500 block mb-1">カテゴリ</label>
                <div className="grid grid-cols-3 gap-1.5">
                  {['学習', '健康', '仕事', '生活', '読書'].map((cat) => (
                    <button
                      key={cat}
                      type="button"
                      onClick={() => setNewTaskCategory(cat)}
                      className={`py-1 text-xs rounded-lg border text-center ${
                        newTaskCategory === cat
                          ? 'bg-[#1C1C1E] text-white border-transparent'
                          : 'bg-slate-50 border-slate-200 text-slate-600'
                      }`}
                    >
                      {cat}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-2">
              <button
                onClick={() => setShowAddTaskModal(false)}
                className="py-2.5 rounded-xl bg-slate-100 text-slate-700 text-xs font-semibold"
              >
                キャンセル
              </button>
              <button
                onClick={() => {
                  if (!newTaskName.trim()) return;
                  onAddTask(newTaskName.trim(), newTaskCategory);
                  setNewTaskName('');
                  setShowAddTaskModal(false);
                }}
                disabled={!newTaskName.trim()}
                className="py-2.5 rounded-xl bg-[#FF0033] text-white text-xs font-semibold disabled:opacity-40"
              >
                追加する
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Edit Task Modal */}
      {editingTask && (
        <div className="fixed inset-0 z-50 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl p-5 w-full max-w-[320px] shadow-2xl">
            <h3 className="text-sm font-bold text-[#1C1C1E] mb-3">タスクを編集</h3>
            <input
              type="text"
              value={editTaskName}
              onChange={(e) => setEditTaskName(e.target.value)}
              className="w-full p-2.5 text-xs border border-slate-200 rounded-xl focus:border-[#FF0033] outline-none mb-4"
            />
            <div className="grid grid-cols-2 gap-2">
              <button
                onClick={() => setEditingTask(null)}
                className="py-2.5 rounded-xl bg-slate-100 text-slate-700 text-xs font-semibold"
              >
                キャンセル
              </button>
              <button
                onClick={() => {
                  if (editTaskName.trim()) {
                    onEditTask(editingTask.id, editTaskName.trim());
                    setEditingTask(null);
                  }
                }}
                className="py-2.5 rounded-xl bg-[#1C1C1E] text-white text-xs font-semibold"
              >
                保存
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Add Routine Modal */}
      {showAddRoutineModal && (
        <div className="fixed inset-0 z-50 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl p-5 w-full max-w-[340px] shadow-2xl">
            <h3 className="text-sm font-bold text-[#1C1C1E] mb-3">新規ルーティーンを作成</h3>
            <div className="mb-3">
              <label className="text-[11px] text-slate-500 block mb-1">ルーティーン名</label>
              <input
                type="text"
                placeholder="例: 夕方の学習セット"
                value={newRoutineName}
                onChange={(e) => setNewRoutineName(e.target.value)}
                className="w-full p-2.5 text-xs border border-slate-200 rounded-xl focus:border-[#FF0033] outline-none"
              />
            </div>

            <div className="mb-4">
              <label className="text-[11px] text-slate-500 block mb-1.5">
                紐付けるタスクを選択 ({selectedTaskIdsForRoutine.length}件)
              </label>
              <div className="space-y-1 max-h-[160px] overflow-y-auto no-scrollbar">
                {tasks.map((task) => {
                  const isChecked = selectedTaskIdsForRoutine.includes(task.id);
                  return (
                    <div
                      key={task.id}
                      onClick={() =>
                        setSelectedTaskIdsForRoutine((prev) =>
                          isChecked ? prev.filter((id) => id !== task.id) : [...prev, task.id]
                        )
                      }
                      className={`p-2 rounded-lg border text-xs cursor-pointer flex items-center justify-between ${
                        isChecked
                          ? 'bg-red-50/60 border-[#FF0033]/40'
                          : 'bg-slate-50 border-slate-200/60'
                      }`}
                    >
                      <span className="truncate">{task.name}</span>
                      <div
                        className={`w-4 h-4 rounded flex items-center justify-center ${
                          isChecked ? 'bg-[#FF0033] text-white' : 'border border-slate-300'
                        }`}
                      >
                        {isChecked && <Check className="w-3 h-3 stroke-[3]" />}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            <div className="grid grid-cols-2 gap-2">
              <button
                onClick={() => setShowAddRoutineModal(false)}
                className="py-2.5 rounded-xl bg-slate-100 text-slate-700 text-xs font-semibold"
              >
                キャンセル
              </button>
              <button
                onClick={() => {
                  if (newRoutineName.trim() && selectedTaskIdsForRoutine.length > 0) {
                    onAddRoutine(newRoutineName.trim(), selectedTaskIdsForRoutine);
                    setNewRoutineName('');
                    setSelectedTaskIdsForRoutine([]);
                    setShowAddRoutineModal(false);
                  }
                }}
                disabled={!newRoutineName.trim() || selectedTaskIdsForRoutine.length === 0}
                className="py-2.5 rounded-xl bg-[#FF0033] text-white text-xs font-semibold disabled:opacity-40"
              >
                作成する
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
