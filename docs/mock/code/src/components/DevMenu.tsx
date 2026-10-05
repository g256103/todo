import React, { useState } from 'react';
import {
  Settings2,
  ChevronDown,
  ChevronUp,
  FastForward,
  RotateCcw,
  ShieldAlert,
  Zap,
  PlayCircle,
  ArrowDownCircle,
  Percent,
} from 'lucide-react';
import { ChallengeStatus } from '../types';

interface DevMenuProps {
  currentStatus: ChallengeStatus | 'NONE';
  onForceStatus: (status: ChallengeStatus | 'NONE') => void;
  isSimulatingReject: boolean;
  onToggleSimulateReject: () => void;
  onSetDeadlineLessThan5s: () => void;
  onFastForwardAutoStart: () => void;
  onToggleCashoutEligible: () => void;
  isCashoutEligible: boolean;
  onResetAllData: () => void;
  // Specific controls requested in prompt:
  onCompleteNextTask: () => void;
  onSetForcedProgress: (progress: number | null) => void;
  forcedProgress: number | null;
  onTriggerRejectAnimation: () => void;
}

export const DevMenu: React.FC<DevMenuProps> = ({
  currentStatus,
  onForceStatus,
  isSimulatingReject,
  onToggleSimulateReject,
  onSetDeadlineLessThan5s,
  onFastForwardAutoStart,
  onToggleCashoutEligible,
  isCashoutEligible,
  onResetAllData,
  onCompleteNextTask,
  onSetForcedProgress,
  forcedProgress,
  onTriggerRejectAnimation,
}) => {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className="fixed top-3 right-3 z-50 select-none">
      {/* Trigger Button */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-[#1C1C1E]/90 text-white text-[11px] font-semibold backdrop-blur-md shadow-lg border border-white/20 hover:bg-black active:scale-95 transition-all"
      >
        <Settings2 className="w-3.5 h-3.5 text-[#34C759]" />
        <span>デモ用操作</span>
        {isOpen ? <ChevronUp className="w-3 h-3" /> : <ChevronDown className="w-3 h-3" />}
      </button>

      {/* Expanded Control Panel */}
      {isOpen && (
        <div className="absolute right-0 mt-2 w-72 bg-white/95 backdrop-blur-xl rounded-2xl shadow-2xl border border-black/10 p-3.5 text-xs text-[#1C1C1E] animate-in fade-in slide-in-from-top-2 duration-150 max-h-[85vh] overflow-y-auto no-scrollbar">
          <div className="flex items-center justify-between pb-2 border-b border-black/10 mb-2.5">
            <span className="font-bold text-[11px] uppercase tracking-wider text-slate-500">
              開発者デモ制御パネル
            </span>
            <span className="text-[10px] text-slate-400">動作検証</span>
          </div>

          {/* New Specific Controls Requested */}
          <div className="space-y-2 mb-3">
            <span className="text-[11px] font-semibold text-slate-700 block mb-1">
              QR・液体チャージ検証:
            </span>

            {/* Complete Next Task (test QR reveal C) */}
            <button
              onClick={onCompleteNextTask}
              disabled={currentStatus !== 'IN_PROGRESS'}
              className="w-full py-2 px-2.5 rounded-xl bg-[#34C759] text-white hover:bg-[#28A745] font-semibold text-[11.5px] flex items-center justify-between shadow-xs disabled:opacity-40 disabled:bg-slate-300"
            >
              <span className="flex items-center gap-1.5">
                <PlayCircle className="w-4 h-4 stroke-[2.5]" />
                次のタスクを完了する
              </span>
              <span className="text-[10px] bg-white/25 px-1.5 py-0.5 rounded font-mono">
                QRセル開放
              </span>
            </button>

            {/* Forced Liquid Progress (0% / 50% / 100%) */}
            <div className="bg-slate-50 p-2 rounded-xl border border-slate-200">
              <span className="text-[10.5px] text-slate-600 block mb-1 font-medium flex items-center gap-1">
                <Percent className="w-3 h-3 text-[#34C759]" />
                長押し液体の水位を強制変更:
              </span>
              <div className="grid grid-cols-4 gap-1">
                {[0, 50, 100].map((val) => (
                  <button
                    key={val}
                    onClick={() => onSetForcedProgress(val)}
                    className={`py-1 text-[10.5px] font-semibold rounded-lg border transition-colors ${
                      forcedProgress === val
                        ? 'bg-[#34C759] text-white border-[#34C759]'
                        : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-100'
                    }`}
                  >
                    {val}%
                  </button>
                ))}
                <button
                  onClick={() => onSetForcedProgress(null)}
                  className="py-1 text-[10px] font-medium rounded-lg bg-white border border-slate-200 text-slate-500 hover:bg-slate-100"
                >
                  解除
                </button>
              </div>
            </div>

            {/* Play Server Reject Animation */}
            <button
              onClick={onTriggerRejectAnimation}
              className="w-full py-1.5 px-2.5 rounded-lg border border-red-200 bg-red-50 hover:bg-red-100 text-[#FF3B30] text-left flex items-center justify-between text-[11px] font-medium"
            >
              <span className="flex items-center gap-1.5">
                <ArrowDownCircle className="w-3.5 h-3.5" />
                サーバー拒否アニメーション再生
              </span>
              <span className="text-[9.5px]">水位下降(600ms)</span>
            </button>
          </div>

          {/* Force State Change */}
          <div className="mb-3 pt-2 border-t border-black/10">
            <span className="text-[11px] font-semibold text-slate-600 block mb-1.5">
              画面・状態の強制切替:
            </span>
            <div className="grid grid-cols-2 gap-1.5">
              <button
                onClick={() => onForceStatus('NONE')}
                className={`py-1.5 px-2 rounded-lg text-[10.5px] font-medium border text-center transition-colors ${
                  currentStatus === 'NONE'
                    ? 'bg-[#1C1C1E] text-white border-black'
                    : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
                }`}
              >
                新規作成
              </button>
              <button
                onClick={() => onForceStatus('WAITING')}
                className={`py-1.5 px-2 rounded-lg text-[10.5px] font-medium border text-center transition-colors ${
                  currentStatus === 'WAITING'
                    ? 'bg-amber-600 text-white border-amber-600'
                    : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
                }`}
              >
                待機中 (5分)
              </button>
              <button
                onClick={() => onForceStatus('IN_PROGRESS')}
                className={`py-1.5 px-2 rounded-lg text-[10.5px] font-medium border text-center transition-colors ${
                  currentStatus === 'IN_PROGRESS'
                    ? 'bg-[#34C759] text-white border-[#34C759]'
                    : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
                }`}
              >
                進行中 (QR/液体)
              </button>
              <button
                onClick={() => onForceStatus('SUCCESS')}
                className={`py-1.5 px-2 rounded-lg text-[10.5px] font-medium border text-center transition-colors ${
                  currentStatus === 'SUCCESS'
                    ? 'bg-[#34C759] text-white border-[#34C759]'
                    : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
                }`}
              >
                成功 (パズル/紙吹雪)
              </button>
              <button
                onClick={() => onForceStatus('FAILED')}
                className={`col-span-2 py-1.5 px-2 rounded-lg text-[10.5px] font-medium border text-center transition-colors ${
                  currentStatus === 'FAILED'
                    ? 'bg-[#FF3B30] text-white border-[#FF3B30]'
                    : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
                }`}
              >
                失敗 (教育pt付与)
              </button>
            </div>
          </div>

          {/* Micro-Interaction Simulations */}
          <div className="space-y-1.5 mb-3 pt-2 border-t border-black/10">
            <span className="text-[11px] font-semibold text-slate-600 block mb-1">
              その他シミュレーション:
            </span>

            {/* Reject simulation toggle */}
            <button
              onClick={onToggleSimulateReject}
              className={`w-full py-1.5 px-2.5 rounded-lg border text-left flex items-center justify-between text-[11px] transition-colors ${
                isSimulatingReject
                  ? 'bg-red-50 border-red-300 text-[#FF3B30] font-semibold'
                  : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
              }`}
            >
              <span className="flex items-center gap-1.5">
                <ShieldAlert className="w-3.5 h-3.5" />
                サーバー拒否モード
              </span>
              <span className="text-[10px] font-mono">
                {isSimulatingReject ? 'ON (拒否)' : 'OFF'}
              </span>
            </button>

            {/* Set deadline < 5s */}
            <button
              onClick={onSetDeadlineLessThan5s}
              className="w-full py-1.5 px-2.5 rounded-lg border border-slate-200 bg-slate-50 hover:bg-slate-100 text-slate-700 text-left flex items-center justify-between text-[11px]"
            >
              <span className="flex items-center gap-1.5">
                <FastForward className="w-3.5 h-3.5 text-amber-600" />
                締切を「残り4秒」にする
              </span>
              <span className="text-[10px] text-slate-400">操作禁止テスト</span>
            </button>

            {/* Fast forward 5 min auto start */}
            <button
              onClick={onFastForwardAutoStart}
              className="w-full py-1.5 px-2.5 rounded-lg border border-slate-200 bg-slate-50 hover:bg-slate-100 text-slate-700 text-left flex items-center justify-between text-[11px]"
            >
              <span className="flex items-center gap-1.5">
                <Zap className="w-3.5 h-3.5 text-blue-600" />
                自動開始カウントダウン即終了
              </span>
              <span className="text-[10px] text-slate-400">即時開始</span>
            </button>

            {/* Cashout condition toggle */}
            <button
              onClick={onToggleCashoutEligible}
              className={`w-full py-1.5 px-2.5 rounded-lg border text-left flex items-center justify-between text-[11px] transition-colors ${
                isCashoutEligible
                  ? 'bg-emerald-50 border-emerald-300 text-[#34C759] font-semibold'
                  : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
              }`}
            >
              <span>現金化条件 (7回/1週間)</span>
              <span className="text-[10px] font-mono">
                {isCashoutEligible ? '達成済' : '未達 (4/7)'}
              </span>
            </button>
          </div>

          {/* Reset All Data */}
          <div className="pt-2 border-t border-black/10">
            <button
              onClick={onResetAllData}
              className="w-full py-1.5 px-2 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 text-[11px] font-medium flex items-center justify-center gap-1"
            >
              <RotateCcw className="w-3 h-3" />
              <span>初期モック状態にリセット</span>
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
