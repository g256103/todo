import React, { useState, useRef } from 'react';
import { HistoryItem } from '../types';
import { CheckCircle2, XCircle, ChevronRight, X } from 'lucide-react';

interface HistoryScreenProps {
  history: HistoryItem[];
}

export const HistoryScreen: React.FC<HistoryScreenProps> = ({ history }) => {
  const [selectedItem, setSelectedItem] = useState<HistoryItem | null>(null);
  const [pressingId, setPressingId] = useState<string | null>(null);
  const pressTimerRef = useRef<NodeJS.Timeout | null>(null);

  const handlePointerDown = (item: HistoryItem) => {
    setPressingId(item.id);
    pressTimerRef.current = setTimeout(() => {
      setSelectedItem(item);
      setPressingId(null);
      if (navigator.vibrate) {
        try {
          navigator.vibrate(50);
        } catch {
          // ignore
        }
      }
    }, 500); // 500ms long press to inspect
  };

  const handlePointerUpOrLeave = () => {
    if (pressTimerRef.current) {
      clearTimeout(pressTimerRef.current);
      pressTimerRef.current = null;
    }
    setPressingId(null);
  };

  return (
    <div className="min-h-full flex flex-col p-4 pb-24">
      {/* Header */}
      <div className="mb-3 pt-1">
        <h1 className="text-lg font-bold text-[#1C1C1E] tracking-tight">チャレンジ履歴</h1>
        <p className="text-xs text-[#8E8E93]">
          長押しで過去のタスク達成内訳（スナップショット）を確認できます
        </p>
      </div>

      {/* History Items List */}
      <div className="space-y-2">
        {history.length === 0 ? (
          <div className="bg-white rounded-2xl border border-black/[0.08] p-8 text-center text-xs text-slate-400">
            まだチャレンジ履歴がありません
          </div>
        ) : (
          history.map((item) => {
            const isSuccess = item.status === 'SUCCESS';
            const isPressing = pressingId === item.id;
            return (
              <div
                key={item.id}
                onPointerDown={() => handlePointerDown(item)}
                onPointerUp={handlePointerUpOrLeave}
                onPointerCancel={handlePointerUpOrLeave}
                onClick={() => setSelectedItem(item)} // Also allow tap for convenience
                className={`bg-white rounded-2xl border border-black/[0.08] p-3.5 shadow-xs transition-all cursor-pointer select-none touch-none ${
                  isPressing
                    ? 'scale-[0.98] border-[#FF0033]/60 bg-red-50/20'
                    : 'hover:border-black/20'
                }`}
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div
                      className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 ${
                        isSuccess
                          ? 'bg-[#34C759]/15 text-[#34C759]'
                          : 'bg-[#FF3B30]/15 text-[#FF3B30]'
                      }`}
                    >
                      {isSuccess ? (
                        <CheckCircle2 className="w-5 h-5 stroke-[2.2]" />
                      ) : (
                        <XCircle className="w-5 h-5 stroke-[2.2]" />
                      )}
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-bold text-[#1C1C1E] tabular-nums">
                          ¥{item.amount.toLocaleString()}
                        </span>
                        <span
                          className={`text-[10px] font-semibold px-2 py-0.5 rounded-full ${
                            isSuccess
                              ? 'bg-[#34C759]/10 text-[#34C759]'
                              : 'bg-[#FF3B30]/10 text-[#FF3B30]'
                          }`}
                        >
                          {isSuccess ? '達成 / 返金' : '未達 / 教育pt'}
                        </span>
                      </div>
                      <span className="text-[11px] text-[#8E8E93] tabular-nums block mt-0.5">
                        {item.date}
                      </span>
                    </div>
                  </div>

                  <div className="flex items-center gap-1 text-[11px] text-[#8E8E93]">
                    <span className="text-[10px] text-slate-400">長押しで詳細</span>
                    <ChevronRight className="w-4 h-4 text-slate-300" />
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* History Detail Modal (Showing completed in green, incomplete in red) */}
      {selectedItem && (
        <div className="fixed inset-0 z-50 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl p-5 w-full max-w-[340px] shadow-2xl animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-center justify-between pb-3 border-b border-black/[0.06] mb-3">
              <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">
                チャレンジ詳細 (スナップショット)
              </span>
              <button
                onClick={() => setSelectedItem(null)}
                className="p-1 rounded-full text-slate-400 hover:bg-slate-100 transition-colors"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="mb-4">
              <div className="flex items-baseline justify-between mb-1">
                <span className="text-xs text-[#8E8E93]">日時: {selectedItem.date}</span>
                <span
                  className={`text-xs font-bold ${
                    selectedItem.status === 'SUCCESS' ? 'text-[#34C759]' : 'text-[#FF3B30]'
                  }`}
                >
                  {selectedItem.status === 'SUCCESS' ? '全タスク達成' : '期限超過・未完了'}
                </span>
              </div>
              <div className="text-2xl font-extrabold text-[#1C1C1E] tabular-nums">
                ¥{selectedItem.amount.toLocaleString()}
              </div>

              {selectedItem.status === 'SUCCESS' ? (
                <div className="mt-2 p-2.5 rounded-xl bg-[#34C759]/10 text-[#34C759] text-xs font-semibold flex items-center justify-between">
                  <span>PayPay残高返金</span>
                  <span className="tabular-nums">+¥{selectedItem.amount.toLocaleString()}</span>
                </div>
              ) : (
                <div className="mt-2 p-2.5 rounded-xl bg-amber-50 text-amber-800 text-xs font-semibold flex items-center justify-between">
                  <span>教育ポイント付与</span>
                  <span className="tabular-nums">+{selectedItem.amount.toLocaleString()} pt</span>
                </div>
              )}
            </div>

            {/* Task list with green (completed) and red (incomplete) */}
            <div className="space-y-2 mb-4">
              <span className="text-xs font-bold text-slate-700 block">
                タスク達成ステータス
              </span>
              <div className="space-y-1.5 max-h-[200px] overflow-y-auto no-scrollbar">
                {selectedItem.tasks.map((task, idx) => (
                  <div
                    key={idx}
                    className={`flex items-center justify-between p-2.5 rounded-xl border text-xs ${
                      task.completed
                        ? 'bg-[#34C759]/10 border-[#34C759]/30 text-[#1C1C1E]'
                        : 'bg-[#FF3B30]/10 border-[#FF3B30]/30 text-[#1C1C1E]'
                    }`}
                  >
                    <span className="truncate max-w-[190px] font-medium">{task.name}</span>
                    <span
                      className={`text-[11px] font-bold shrink-0 ${
                        task.completed ? 'text-[#34C759]' : 'text-[#FF3B30]'
                      }`}
                    >
                      {task.completed ? '完了 (緑)' : '未完了 (赤)'}
                    </span>
                  </div>
                ))}
              </div>
            </div>

            <button
              onClick={() => setSelectedItem(null)}
              className="w-full py-2.5 rounded-xl bg-[#1C1C1E] text-white text-xs font-semibold hover:bg-black active:scale-98 transition-transform"
            >
              閉じる
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
