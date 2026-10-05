import React, { useState } from 'react';
import { Coins, BookOpen, AlertCircle, CheckCircle2, ChevronRight, ArrowDownRight, Award, Calendar } from 'lucide-react';
import { EXCHANGE_ITEMS } from '../mockData';
import { PointTransaction } from '../types';

interface PointsScreenProps {
  points: number;
  successCount: number; // e.g. 4/7
  streakDays: number; // e.g. 4 days (needs 7 days = 1 week)
  transactions: PointTransaction[];
  onExchange: (itemId: string, pointsNeeded: number, itemName: string) => void;
  onCashout: (pointsAmount: number) => void;
}

export const PointsScreen: React.FC<PointsScreenProps> = ({
  points,
  successCount,
  streakDays,
  transactions,
  onExchange,
  onCashout,
}) => {
  const [showCashoutModal, setShowCashoutModal] = useState(false);
  const [cashoutPointsInput, setCashoutPointsInput] = useState<number>(1000);
  const [cashoutDoneMsg, setCashoutDoneMsg] = useState<string | null>(null);

  // Requirements for cashout: 7 successes AND at least 1 week (7 days) continuation
  const isSuccessEligible = successCount >= 7;
  const isStreakEligible = streakDays >= 7;
  const isCashoutEligible = isSuccessEligible && isStreakEligible;

  const handleApplyCashout = () => {
    if (!isCashoutEligible) return;
    if (cashoutPointsInput > points) return;

    const fee = Math.floor(cashoutPointsInput * 0.1);
    const cash = cashoutPointsInput - fee;
    onCashout(cashoutPointsInput);
    setCashoutDoneMsg(`¥${cash.toLocaleString()} の振込申請を受け付けました (手数料: ${fee} pt)`);
    setTimeout(() => {
      setShowCashoutModal(false);
      setCashoutDoneMsg(null);
    }, 1800);
  };

  return (
    <div className="min-h-full flex flex-col p-4 pb-24">
      {/* Screen Title */}
      <div className="mb-3 pt-1">
        <h1 className="text-lg font-bold text-[#1C1C1E] tracking-tight">ポイント & 還元</h1>
        <p className="text-xs text-[#8E8E93]">
          未達成時のコミット額は教育ポイントとして自己投資に活用できます
        </p>
      </div>

      {/* Balance Card */}
      <div className="bg-white rounded-2xl border border-black/[0.08] p-4 shadow-xs mb-3.5">
        <div className="flex items-center justify-between mb-1">
          <span className="text-xs text-slate-500 font-medium">保有教育ポイント</span>
          <span className="text-[10.5px] font-semibold text-amber-700 bg-amber-50 px-2 py-0.5 rounded-full">
            有効期限 3か月・譲渡不可
          </span>
        </div>

        <div className="flex items-baseline gap-1 my-1">
          <span className="text-3xl font-extrabold text-[#1C1C1E] tabular-nums tracking-tight">
            {points.toLocaleString()}
          </span>
          <span className="text-sm font-semibold text-slate-600">pt</span>
        </div>

        {/* Progress Toward Cashout */}
        <div className="mt-3 pt-3 border-t border-black/[0.06]">
          <div className="flex justify-between items-center text-xs mb-1.5">
            <span className="font-semibold text-slate-700 flex items-center gap-1">
              <Award className="w-3.5 h-3.5 text-amber-500" />
              現金化条件の達成状況
            </span>
            <span className="tabular-nums font-bold text-[#1C1C1E]">
              {Math.min(successCount, 7)}/7 回達成
            </span>
          </div>

          <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden mb-2">
            <div
              className="bg-[#FF0033] h-full rounded-full transition-all duration-300"
              style={{ width: `${Math.min((successCount / 7) * 100, 100)}%` }}
            />
          </div>

          <div className="flex items-center justify-between text-[11px] text-slate-500">
            <span>継続日数: {streakDays}日 (あと{Math.max(0, 7 - streakDays)}日で1週間)</span>
            <button
              onClick={() => setShowCashoutModal(true)}
              className="text-[#FF0033] font-semibold hover:underline"
            >
              現金化申請 {'>'}
            </button>
          </div>
        </div>
      </div>

      {/* Exchangeable Items: Books, Learning, Qualifications */}
      <div className="bg-white rounded-2xl border border-black/[0.08] p-4 shadow-xs mb-3.5">
        <h2 className="text-xs font-bold text-slate-700 uppercase tracking-wider mb-2.5 flex items-center justify-between">
          <span>教育・学習教材との交換</span>
          <BookOpen className="w-3.5 h-3.5 text-slate-400" />
        </h2>

        <div className="space-y-2">
          {EXCHANGE_ITEMS.map((item) => {
            const canAfford = points >= item.points;
            return (
              <div
                key={item.id}
                className="p-3 rounded-xl border border-black/[0.06] bg-[#F5F5F7]/40 flex items-center justify-between gap-3"
              >
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-1.5">
                    <span className="text-[10px] font-semibold text-blue-600 bg-blue-50 px-1.5 py-0.5 rounded">
                      {item.category}
                    </span>
                    <span className="text-xs font-semibold text-[#1C1C1E] truncate">
                      {item.title}
                    </span>
                  </div>
                  <p className="text-[10.5px] text-[#8E8E93] mt-0.5 truncate">
                    {item.description}
                  </p>
                  <span className="text-xs font-bold text-amber-600 tabular-nums mt-1 block">
                    {item.points.toLocaleString()} pt
                  </span>
                </div>

                <button
                  onClick={() => onExchange(item.id, item.points, item.title)}
                  disabled={!canAfford}
                  className="py-1.5 px-3 rounded-lg text-xs font-semibold shrink-0 transition-all disabled:opacity-40 disabled:bg-slate-200 disabled:text-slate-400 bg-[#1C1C1E] text-white hover:bg-black active:scale-95"
                >
                  交換
                </button>
              </div>
            );
          })}
        </div>
      </div>

      {/* Point History / Expiry */}
      <div className="bg-white rounded-2xl border border-black/[0.08] p-4 shadow-xs">
        <h2 className="text-xs font-bold text-slate-700 uppercase tracking-wider mb-2 flex items-center justify-between">
          <span>ポイント履歴・失効予定</span>
          <Calendar className="w-3.5 h-3.5 text-slate-400" />
        </h2>

        <div className="space-y-2">
          {transactions.map((tx) => (
            <div
              key={tx.id}
              className="flex items-center justify-between py-1.5 border-b border-black/[0.04] last:border-none text-xs"
            >
              <div>
                <span className="font-medium text-slate-800 block truncate max-w-[200px]">
                  {tx.title}
                </span>
                <span className="text-[10px] text-slate-400">
                  失効日: {tx.expiresAt} (3か月)
                </span>
              </div>
              <span
                className={`font-bold tabular-nums ${
                  tx.amount > 0 ? 'text-amber-600' : 'text-[#FF3B30]'
                }`}
              >
                {tx.amount > 0 ? `+${tx.amount}` : tx.amount} pt
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Cashout Modal */}
      {showCashoutModal && (
        <div className="fixed inset-0 z-50 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl p-5 w-full max-w-[340px] shadow-2xl text-left">
            <h3 className="text-base font-bold text-[#1C1C1E] mb-1">ポイント現金化</h3>
            <p className="text-xs text-[#8E8E93] mb-4">
              7回以上の成功かつ1週間以上の継続で申請可能です（手数料10%）
            </p>

            {cashoutDoneMsg ? (
              <div className="p-4 bg-emerald-50 rounded-xl text-center text-xs font-semibold text-emerald-800">
                <CheckCircle2 className="w-6 h-6 text-emerald-600 mx-auto mb-1" />
                {cashoutDoneMsg}
              </div>
            ) : !isCashoutEligible ? (
              <div className="space-y-3">
                <div className="p-3 rounded-xl bg-amber-50 border border-amber-200/60 text-xs text-amber-900 flex items-start gap-2">
                  <AlertCircle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
                  <div>
                    <span className="font-bold block">申請条件を満たしていません</span>
                    <ul className="list-disc list-inside mt-1 space-y-0.5 text-[11px] text-amber-800">
                      <li>7回成功: 現在 {successCount}/7回 {!isSuccessEligible && '(未達)'}</li>
                      <li>1週間継続: 現在 {streakDays}/7日 {!isStreakEligible && '(未達)'}</li>
                    </ul>
                  </div>
                </div>
                <button
                  onClick={() => setShowCashoutModal(false)}
                  className="w-full py-2.5 rounded-xl bg-slate-100 text-slate-700 text-xs font-semibold"
                >
                  閉じる
                </button>
              </div>
            ) : (
              <div className="space-y-3 text-xs">
                <div>
                  <label className="block text-slate-600 mb-1 font-medium">申請ポイント</label>
                  <input
                    type="number"
                    min="100"
                    max={points}
                    step="100"
                    value={cashoutPointsInput}
                    onChange={(e) => setCashoutPointsInput(Number(e.target.value))}
                    className="w-full p-2.5 border border-slate-200 rounded-xl tabular-nums font-bold text-base focus:border-[#FF0033] outline-none"
                  />
                  <span className="text-[10px] text-slate-400">保有: {points} pt</span>
                </div>

                <div className="p-3 bg-slate-50 rounded-xl space-y-1 text-slate-600">
                  <div className="flex justify-between">
                    <span>申請額</span>
                    <span className="font-semibold tabular-nums">{cashoutPointsInput} pt</span>
                  </div>
                  <div className="flex justify-between text-[#FF3B30]">
                    <span>振込手数料 (10%)</span>
                    <span className="font-semibold tabular-nums">
                      -{Math.floor(cashoutPointsInput * 0.1)} pt
                    </span>
                  </div>
                  <div className="flex justify-between font-bold text-slate-900 border-t pt-1">
                    <span>振込予定額</span>
                    <span className="tabular-nums">
                      ¥{(cashoutPointsInput - Math.floor(cashoutPointsInput * 0.1)).toLocaleString()}
                    </span>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-2 pt-2">
                  <button
                    onClick={() => setShowCashoutModal(false)}
                    className="py-2.5 rounded-xl bg-slate-100 text-slate-700 font-semibold"
                  >
                    キャンセル
                  </button>
                  <button
                    onClick={handleApplyCashout}
                    disabled={cashoutPointsInput > points || cashoutPointsInput <= 0}
                    className="py-2.5 rounded-xl bg-[#FF0033] text-white font-semibold disabled:opacity-40"
                  >
                    申請する
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
