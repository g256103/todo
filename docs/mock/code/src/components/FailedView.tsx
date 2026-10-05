import React from 'react';
import { AlertCircle, Coins, ArrowRight, RotateCcw } from 'lucide-react';
import { ChallengeTask } from '../types';

interface FailedViewProps {
  amount: number;
  tasks: ChallengeTask[];
  onGoToPoints: () => void;
  onResetToNewChallenge: () => void;
}

export const FailedView: React.FC<FailedViewProps> = ({
  amount,
  tasks,
  onGoToPoints,
  onResetToNewChallenge,
}) => {
  const completedCount = tasks.filter((t) => t.status === 'COMPLETED').length;

  return (
    <div className="min-h-full flex flex-col items-center justify-between p-5 pb-24 text-center">
      <div className="w-full flex flex-col items-center pt-2">
        {/* Failed Icon */}
        <div className="w-14 h-14 rounded-full bg-[#FF3B30]/10 flex items-center justify-center text-[#FF3B30] mb-3">
          <AlertCircle className="w-8 h-8 stroke-[2.2]" />
        </div>

        <h1 className="text-xl font-bold tracking-tight text-[#1C1C1E] mb-1">
          チャレンジ終了 (FAILED)
        </h1>
        <p className="text-xs text-[#8E8E93] mb-4">
          締切時刻までに全タスクが完了しませんでした ({completedCount}/{tasks.length} 完了)
        </p>

        {/* Educational Point Grant Banner */}
        <div className="w-full bg-white rounded-2xl border border-black/[0.08] p-4 shadow-sm text-left mb-4">
          <div className="flex items-center gap-2 mb-2">
            <div className="w-7 h-7 rounded-lg bg-amber-500/15 flex items-center justify-center text-amber-600">
              <Coins className="w-4 h-4" />
            </div>
            <div>
              <span className="text-xs font-semibold text-[#1C1C1E] block">
                教育用ポイントとして付与
              </span>
              <span className="text-[10.5px] text-[#8E8E93]">
                返金されなかったコミット金額が振替付与されました
              </span>
            </div>
          </div>

          <div className="bg-[#F5F5F7] rounded-xl p-3 flex items-center justify-between mb-3">
            <span className="text-xs text-slate-600">付与されたポイント</span>
            <span className="text-xl font-bold text-amber-600 tabular-nums">
              +{amount.toLocaleString()} <span className="text-xs font-semibold">pt</span>
            </span>
          </div>

          <div className="text-[11px] text-slate-500 space-y-1">
            <p>・書籍・プログラミング教材・資格学習などの自己投資に利用できます。</p>
            <p>・ポイント有効期限: 付与から3か月（譲渡不可）</p>
          </div>
        </div>

        {/* Task completion result breakdown */}
        <div className="w-full bg-white rounded-2xl border border-black/[0.08] p-4 shadow-sm text-left">
          <span className="text-xs font-semibold text-[#1C1C1E] block mb-2.5">
            タスク達成結果
          </span>
          <div className="space-y-2">
            {tasks.map((task) => (
              <div
                key={task.id}
                className="flex items-center justify-between text-xs py-1.5 border-b border-black/[0.04] last:border-none"
              >
                <span className="truncate max-w-[200px] text-slate-800">
                  {task.taskNameSnapshot}
                </span>
                <span
                  className={`font-medium text-[11px] ${
                    task.status === 'COMPLETED' ? 'text-[#34C759]' : 'text-[#FF3B30]'
                  }`}
                >
                  {task.status === 'COMPLETED' ? '完了' : '未完了'}
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Action Buttons */}
      <div className="w-full pt-4 space-y-2">
        <button
          onClick={onGoToPoints}
          className="w-full py-3 px-4 rounded-xl bg-[#1C1C1E] text-white font-semibold text-xs hover:bg-black active:scale-98 transition-transform shadow-xs flex items-center justify-center gap-2"
        >
          <span>ポイント残高・交換商品を見る</span>
          <ArrowRight className="w-3.5 h-3.5" />
        </button>

        <button
          onClick={onResetToNewChallenge}
          className="w-full py-3 px-4 rounded-xl bg-white border border-black/[0.1] text-slate-700 font-semibold text-xs hover:bg-slate-50 active:scale-98 transition-transform flex items-center justify-center gap-1.5"
        >
          <RotateCcw className="w-3.5 h-3.5" />
          <span>新しくチャレンジを作成する</span>
        </button>
      </div>
    </div>
  );
};
