import React, { ReactNode, useState, useEffect } from 'react';
import { Wifi, Signal, BatteryCharging } from 'lucide-react';

interface PhoneFrameProps {
  children: ReactNode;
  devMenu?: ReactNode;
}

export const PhoneFrame: React.FC<PhoneFrameProps> = ({ children, devMenu }) => {
  const [time, setTime] = useState('09:41');

  useEffect(() => {
    const updateTime = () => {
      const now = new Date();
      const hours = String(now.getHours()).padStart(2, '0');
      const minutes = String(now.getMinutes()).padStart(2, '0');
      setTime(`${hours}:${minutes}`);
    };
    updateTime();
    const interval = setInterval(updateTime, 30000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="min-h-screen bg-[#E5E5EA] flex items-center justify-center p-0 md:p-6 relative select-none">
      {/* Floating Developer Menu on desktop/tablet or corner overlay */}
      {devMenu}

      {/* Smartphone Body Frame */}
      <div className="w-full md:w-[393px] h-screen md:h-[844px] md:max-h-[92vh] bg-[#F5F5F7] md:rounded-[44px] shadow-2xl md:ring-1 md:ring-black/10 overflow-hidden flex flex-col relative">
        {/* Dynamic Island / Speaker cutout on desktop */}
        <div className="hidden md:block absolute top-0 left-1/2 -translate-x-1/2 z-50 pointer-events-none">
          <div className="w-[120px] h-[28px] bg-black rounded-b-[18px] flex items-center justify-center">
            <div className="w-3 h-3 rounded-full bg-[#1c1c1e] mr-2"></div>
            <div className="w-2.5 h-2.5 rounded-full bg-[#0d0d10]"></div>
          </div>
        </div>

        {/* iOS-Style Status Bar */}
        <header className="h-11 px-7 flex items-center justify-between text-xs font-semibold text-[#1C1C1E] z-40 bg-transparent shrink-0">
          <span className="tabular-nums tracking-tight font-medium text-[14px]">{time}</span>
          <div className="flex items-center gap-1.5 text-[#1C1C1E]">
            <Signal className="w-3.5 h-3.5 stroke-[2.2]" />
            <Wifi className="w-3.5 h-3.5 stroke-[2.2]" />
            <div className="flex items-center gap-0.5">
              <span className="text-[11px] font-medium tabular-nums mr-0.5">100%</span>
              <BatteryCharging className="w-4 h-4 text-[#34C759] fill-[#34C759]/20" />
            </div>
          </div>
        </header>

        {/* Screen Viewport with internal scrolling */}
        <main className="flex-1 overflow-y-auto no-scrollbar relative flex flex-col">
          {children}
        </main>

        {/* Home Indicator Bar */}
        <div className="h-5 bg-transparent flex items-center justify-center shrink-0 pointer-events-none z-50">
          <div className="w-32 h-1 bg-black/25 rounded-full"></div>
        </div>
      </div>
    </div>
  );
};
