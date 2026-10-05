import React from 'react';
import { Target, Coins, History, Layers, Settings } from 'lucide-react';
import { TabType } from '../types';

interface BottomNavProps {
  currentTab: TabType;
  onTabChange: (tab: TabType) => void;
}

export const BottomNav: React.FC<BottomNavProps> = ({ currentTab, onTabChange }) => {
  const tabs: { id: TabType; label: string; icon: React.FC<{ className?: string }> }[] = [
    { id: 'main', label: 'メイン', icon: Target },
    { id: 'points', label: 'ポイント', icon: Coins },
    { id: 'history', label: '履歴', icon: History },
    { id: 'edit', label: '編集', icon: Layers },
    { id: 'settings', label: '設定', icon: Settings },
  ];

  return (
    <nav
      role="navigation"
      aria-label="主要ナビゲーション"
      className="absolute bottom-0 left-0 right-0 z-40 border-t border-[rgba(0,0,0,0.08)] glass-nav transition-all duration-200"
      style={{
        background: 'rgba(255, 255, 255, 0.76)',
        backdropFilter: 'blur(20px) saturate(180%)',
        WebkitBackdropFilter: 'blur(20px) saturate(180%)',
      }}
    >
      <div className="grid grid-cols-5 h-[62px] px-1 items-center">
        {tabs.map((tab) => {
          const isActive = currentTab === tab.id;
          const Icon = tab.icon;
          return (
            <button
              key={tab.id}
              onClick={() => onTabChange(tab.id)}
              className={`flex flex-col items-center justify-center h-full min-h-[44px] transition-transform active:scale-95 ${
                isActive ? 'text-[#FF0033]' : 'text-[#8E8E93] hover:text-[#1C1C1E]'
              }`}
            >
              <Icon
                className={`w-[22px] h-[22px] transition-colors stroke-[2] ${
                  isActive ? 'text-[#FF0033]' : 'text-[#8E8E93]'
                }`}
              />
              <span
                className={`text-[10.5px] font-medium tracking-tight mt-1 tabular-nums ${
                  isActive ? 'text-[#FF0033] font-semibold' : 'text-[#8E8E93]'
                }`}
              >
                {tab.label}
              </span>
            </button>
          );
        })}
      </div>
    </nav>
  );
};
