import React, { useState } from 'react';
import { UserProfile } from '../types';
import { User, ShieldCheck, FileText, Smartphone, ChevronRight, X, HeartHandshake } from 'lucide-react';

interface SettingsScreenProps {
  user: UserProfile;
  onToggleAccessibleMode: (enabled: boolean) => void;
  onUpdateUserName: (name: string) => void;
}

export const SettingsScreen: React.FC<SettingsScreenProps> = ({
  user,
  onToggleAccessibleMode,
  onUpdateUserName,
}) => {
  const [showTermsModal, setShowTermsModal] = useState(false);
  const [isEditingName, setIsEditingName] = useState(false);
  const [tempName, setTempName] = useState(user.name);

  return (
    <div className="min-h-full flex flex-col p-4 pb-24">
      {/* Title */}
      <div className="mb-3 pt-1">
        <h1 className="text-lg font-bold text-[#1C1C1E] tracking-tight">設定</h1>
        <p className="text-xs text-[#8E8E93]">アカウント設定とアクセシビリティ操作</p>
      </div>

      {/* Profile Card */}
      <div className="bg-white rounded-2xl border border-black/[0.08] p-4 shadow-xs mb-3.5 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 rounded-full bg-[#1C1C1E] text-white flex items-center justify-center font-bold text-base">
            {user.name.slice(0, 1)}
          </div>
          <div>
            {isEditingName ? (
              <div className="flex items-center gap-1.5">
                <input
                  type="text"
                  value={tempName}
                  onChange={(e) => setTempName(e.target.value)}
                  className="p-1 text-xs border border-slate-300 rounded font-semibold w-28 outline-none"
                />
                <button
                  onClick={() => {
                    onUpdateUserName(tempName);
                    setIsEditingName(false);
                  }}
                  className="text-xs font-semibold text-[#FF0033] px-1"
                >
                  保存
                </button>
              </div>
            ) : (
              <div className="flex items-center gap-2">
                <span className="text-sm font-bold text-[#1C1C1E]">{user.name}</span>
                <button
                  onClick={() => setIsEditingName(true)}
                  className="text-[11px] text-slate-400 hover:text-slate-600 underline"
                >
                  変更
                </button>
              </div>
            )}
            <span className="text-[11px] text-[#8E8E93] block">{user.email}</span>
            <span className="text-[10px] text-slate-400 font-mono">ID: {user.id}</span>
          </div>
        </div>
      </div>

      {/* Accessibility & Input Mode Section */}
      <div className="bg-white rounded-2xl border border-black/[0.08] p-4 shadow-xs mb-3.5">
        <span className="text-xs font-bold text-slate-700 uppercase tracking-wider block mb-2">
          アクセシビリティ・支援機能 (デモ用)
        </span>

        <div className="flex items-center justify-between py-2 border-b border-black/[0.04]">
          <div className="pr-4">
            <span className="text-xs font-semibold text-[#1C1C1E] block">
              確認ダイアログによる代替完了
            </span>
            <span className="text-[11px] text-[#8E8E93]">
              スクリーンリーダー等の支援機能利用時、4秒長押しの代わりに「OK確認ダイアログ」で完了できます。
            </span>
          </div>

          {/* iOS-Style Toggle Switch */}
          <button
            role="switch"
            aria-checked={user.accessibleMode}
            onClick={() => onToggleAccessibleMode(!user.accessibleMode)}
            className={`w-12 h-7 rounded-full p-1 transition-colors duration-200 ease-in-out shrink-0 ${
              user.accessibleMode ? 'bg-[#34C759]' : 'bg-slate-300'
            }`}
          >
            <div
              className={`w-5 h-5 bg-white rounded-full shadow-md transform transition-transform duration-200 ease-in-out ${
                user.accessibleMode ? 'translate-x-5' : 'translate-x-0'
              }`}
            />
          </button>
        </div>

        <div className="pt-2 text-[10.5px] text-slate-500">
          現在のモード:{' '}
          <span className="font-semibold text-slate-800">
            {user.accessibleMode ? 'ダイアログ完了モード' : '4秒長押し充電モード'}
          </span>
        </div>
      </div>

      {/* Legal & App Information */}
      <div className="bg-white rounded-2xl border border-black/[0.08] p-4 shadow-xs space-y-2">
        <span className="text-xs font-bold text-slate-700 uppercase tracking-wider block mb-1">
          規約・システム情報
        </span>

        <button
          onClick={() => setShowTermsModal(true)}
          className="w-full flex items-center justify-between py-2 border-b border-black/[0.04] text-xs text-left"
        >
          <div className="flex items-center gap-2 text-slate-800">
            <FileText className="w-4 h-4 text-slate-400" />
            <span>利用規約 (ToDoコミット・返金原則)</span>
          </div>
          <ChevronRight className="w-4 h-4 text-slate-300" />
        </button>

        <div className="flex items-center justify-between py-2 border-b border-black/[0.04] text-xs">
          <div className="flex items-center gap-2 text-slate-800">
            <ShieldCheck className="w-4 h-4 text-slate-400" />
            <span>モックPayPay決済システム</span>
          </div>
          <span className="text-[11px] text-[#34C759] font-medium">モック接続稼働中</span>
        </div>

        <div className="flex items-center justify-between py-2 text-xs">
          <div className="flex items-center gap-2 text-slate-800">
            <Smartphone className="w-4 h-4 text-slate-400" />
            <span>アプリバージョン</span>
          </div>
          <span className="text-[11px] text-slate-500 font-mono">v3.0.0-mock</span>
        </div>
      </div>

      {/* Terms Modal */}
      {showTermsModal && (
        <div className="fixed inset-0 z-50 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl p-5 w-full max-w-[340px] shadow-2xl flex flex-col max-h-[80vh]">
            <div className="flex items-center justify-between pb-3 border-b border-black/[0.06] mb-3">
              <h3 className="text-sm font-bold text-[#1C1C1E]">ToDoコミット 利用規約</h3>
              <button
                onClick={() => setShowTermsModal(false)}
                className="p-1 rounded-full text-slate-400 hover:bg-slate-100"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto no-scrollbar text-xs text-slate-600 space-y-3 leading-relaxed pr-1">
              <div>
                <h4 className="font-bold text-[#1C1C1E] mb-1">第1条（コミット金額と返金）</h4>
                <p>
                  ユーザーはチャレンジ開始前に100円〜5000円（100円単位）のコミット額をデポジットします。設定された絶対期限内に全タスクが完了した場合、コミット額全額が即座に返金されます。
                </p>
              </div>
              <div>
                <h4 className="font-bold text-[#1C1C1E] mb-1">第2条（未達成時の教育ポイント）</h4>
                <p>
                  期限内に全タスクが完了しなかった場合、未返金分は全額教育ポイントとしてユーザーアカウントに付与されます。ポイントは書籍・自己啓発・資格教材等との交換に利用可能です。有効期限は3か月、第三者への譲渡は不可となります。
                </p>
              </div>
              <div>
                <h4 className="font-bold text-[#1C1C1E] mb-1">第3条（現金化条件）</h4>
                <p>
                  ポイントの現金化は、7回以上の成功かつ1週間以上の継続を達成したユーザーに限り申請可能です。現金化に際しては一律10%の手数料が差し引かれます。
                </p>
              </div>
              <div>
                <h4 className="font-bold text-[#1C1C1E] mb-1">第4条（自動開始仕様）</h4>
                <p>
                  決済完了後、ユーザーが「始める」を押下しない場合でも、5分後にサーバー時刻基準で自動的にチャレンジが開始されます。
                </p>
              </div>
            </div>

            <button
              onClick={() => setShowTermsModal(false)}
              className="mt-4 w-full py-2.5 rounded-xl bg-[#1C1C1E] text-white text-xs font-semibold hover:bg-black active:scale-98 transition-transform"
            >
              確認しました
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
