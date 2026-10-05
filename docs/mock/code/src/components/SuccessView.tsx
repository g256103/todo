import React, { useEffect, useState, useRef, useMemo } from 'react';
import confetti from 'canvas-confetti';
import QRCode from 'qrcode';
import { CheckCircle2, RotateCcw, ShieldCheck, Sparkles } from 'lucide-react';

interface SuccessViewProps {
  amount: number;
  qrToken?: string;
  onResetToNewChallenge: () => void;
}

export const SuccessView: React.FC<SuccessViewProps> = ({
  amount,
  qrToken = `paypay-commit-${Math.random().toString(36).substring(2, 9)}`,
  onResetToNewChallenge,
}) => {
  const [qrDataUrl, setQrDataUrl] = useState<string>('');
  const [puzzleAssembled, setPuzzleAssembled] = useState(false);
  const [qrStatus, setQrStatus] = useState<'AVAILABLE' | 'USED'>('AVAILABLE');
  const [shakeScreen, setShakeScreen] = useState(false);
  const hasTriggeredRef = useRef(false);

  // Generate genuine scannable QR Code with quiet zone
  useEffect(() => {
    const payload = `https://paypay-commit.mock/claim?token=${qrToken}&amount=${amount}&status=VERIFIED`;
    QRCode.toDataURL(payload, {
      width: 240,
      margin: 2, // 2-module quiet zone for rapid camera scan
      color: {
        dark: '#1C1C1E',
        light: '#FFFFFF',
      },
    })
      .then((url) => {
        setQrDataUrl(url);
      })
      .catch((err) => {
        console.error('QR generation error:', err);
      });
  }, [amount, qrToken]);

  // 4x4 Puzzle Pieces (16 tiles) configuration with deterministic scatter positions
  const puzzlePieces = useMemo(() => {
    const pieces = [];
    const seedTable = [
      { rx: -120, ry: -140, rot: -25 },
      { rx: 30, ry: -160, rot: 15 },
      { rx: 110, ry: -130, rot: -20 },
      { rx: 140, ry: -80, rot: 30 },
      { rx: -150, ry: -40, rot: -35 },
      { rx: -60, ry: -30, rot: 12 },
      { rx: 70, ry: -20, rot: -18 },
      { rx: 150, ry: -10, rot: 25 },
      { rx: -140, ry: 40, rot: 20 },
      { rx: -50, ry: 50, rot: -15 },
      { rx: 60, ry: 60, rot: 28 },
      { rx: 130, ry: 70, rot: -22 },
      { rx: -110, ry: 130, rot: -30 },
      { rx: -20, ry: 150, rot: 18 },
      { rx: 80, ry: 140, rot: -12 },
      { rx: 140, ry: 120, rot: 32 },
    ];

    for (let r = 0; r < 4; r++) {
      for (let c = 0; c < 4; c++) {
        const id = r * 4 + c;
        pieces.push({
          id,
          row: r,
          col: c,
          ...seedTable[id % seedTable.length],
        });
      }
    }
    return pieces;
  }, []);

  // Trigger celebration, confetti, vibration, puzzle
  useEffect(() => {
    if (hasTriggeredRef.current) return;
    hasTriggeredRef.current = true;

    // Vibration API test
    let vibrationSuccess = false;
    if (navigator.vibrate) {
      try {
        vibrationSuccess = navigator.vibrate([120, 80, 200, 100, 150]);
      } catch {
        vibrationSuccess = false;
      }
    }
    if (!vibrationSuccess) {
      setShakeScreen(true);
      setTimeout(() => setShakeScreen(false), 500);
    }

    // Initial confetti
    confetti({
      particleCount: 70,
      spread: 60,
      origin: { y: 0.6 },
      colors: ['#34C759', '#FFD60A', '#FF0033', '#007AFF'],
    });

    // Animate 4x4 puzzle pieces assembling
    const timer = setTimeout(() => {
      setPuzzleAssembled(true);
      // Secondary burst when puzzle clicks into place
      setTimeout(() => {
        confetti({
          particleCount: 50,
          spread: 80,
          origin: { y: 0.45 },
          colors: ['#34C759', '#FF0033', '#FFD60A'],
        });
      }, 700);
    }, 400);

    return () => clearTimeout(timer);
  }, []);

  const handleUseQR = () => {
    if (qrStatus === 'USED') return;
    setQrStatus('USED');
    if (navigator.vibrate) {
      try {
        navigator.vibrate(100);
      } catch {
        // ignore
      }
    }
  };

  const qrBoxSize = 220; // 220px total size
  const tileSize = qrBoxSize / 4; // 55px per tile

  return (
    <div
      className={`min-h-full flex flex-col items-center justify-between p-5 pb-24 text-center transition-transform ${
        shakeScreen ? 'animate-bounce' : ''
      }`}
    >
      <div className="w-full flex flex-col items-center pt-2">
        {/* Success Icon */}
        <div className="w-13 h-13 rounded-full bg-[#34C759]/15 flex items-center justify-center text-[#34C759] mb-2.5 shadow-xs">
          <CheckCircle2 className="w-7 h-7 stroke-[2.8]" />
        </div>

        <h1 className="text-xl font-bold tracking-tight text-[#1C1C1E] mb-0.5 flex items-center gap-1.5 justify-center">
          <span>おめでとうございます！</span>
          <Sparkles className="w-4 h-4 text-amber-500 fill-amber-400" />
        </h1>
        <p className="text-xs text-[#8E8E93] mb-3.5">全タスクを達成し、QRコードが完成しました</p>

        {/* Refund Banner */}
        <div className="w-full bg-[#34C759]/10 border border-[#34C759]/30 rounded-xl p-3 mb-4 flex items-center justify-between text-left">
          <div>
            <span className="text-[10.5px] font-semibold text-[#34C759] block uppercase tracking-wider">
              返金完了 (モック)
            </span>
            <span className="text-xs text-slate-700">コミット金額がPayPay残高へ返金されました</span>
          </div>
          <div className="text-right">
            <span className="text-base font-bold text-[#1C1C1E] tabular-nums">
              +¥{amount.toLocaleString()}
            </span>
          </div>
        </div>

        {/* 4x4 Puzzle Assembly & QR Code Stage */}
        <div className="w-full max-w-[280px] bg-white rounded-2xl border border-black/[0.08] p-4 shadow-sm flex flex-col items-center relative overflow-hidden">
          <div className="text-[11px] font-medium text-slate-500 mb-2 flex items-center gap-1">
            <ShieldCheck className="w-3.5 h-3.5 text-[#34C759]" />
            達成証明 QRコード（実機カメラ読取対応）
          </div>

          <div
            className="relative bg-white rounded-xl flex items-center justify-center border border-slate-100 overflow-hidden shadow-2xs"
            style={{ width: `${qrBoxSize}px`, height: `${qrBoxSize}px` }}
          >
            {qrDataUrl ? (
              <div className="relative w-full h-full">
                {/* 4x4 Puzzle Pieces Layer */}
                {!puzzleAssembled ? (
                  <div className="absolute inset-0 pointer-events-none">
                    {puzzlePieces.map((piece) => (
                      <div
                        key={piece.id}
                        className="absolute overflow-hidden transition-all duration-700 ease-out border border-slate-200/50 shadow-sm"
                        style={{
                          width: `${tileSize}px`,
                          height: `${tileSize}px`,
                          left: `${piece.col * tileSize}px`,
                          top: `${piece.row * tileSize}px`,
                          transform: `translate(${piece.rx}px, ${piece.ry}px) rotate(${piece.rot}deg)`,
                          zIndex: 10,
                        }}
                      >
                        {/* Slice of QR code */}
                        <div
                          style={{
                            width: `${qrBoxSize}px`,
                            height: `${qrBoxSize}px`,
                            marginLeft: `-${piece.col * tileSize}px`,
                            marginTop: `-${piece.row * tileSize}px`,
                            backgroundImage: `url(${qrDataUrl})`,
                            backgroundSize: `${qrBoxSize}px ${qrBoxSize}px`,
                          }}
                        />
                      </div>
                    ))}
                  </div>
                ) : (
                  /* Assembled Full Seamless QR Image */
                  <div className="relative w-full h-full flex items-center justify-center animate-in zoom-in-95 duration-300">
                    <img
                      src={qrDataUrl}
                      alt="達成証明QRコード"
                      className={`w-[220px] h-[220px] transition-all duration-300 ${
                        qrStatus === 'USED' ? 'grayscale opacity-40' : ''
                      }`}
                    />

                    {/* Stamp if QR is used */}
                    {qrStatus === 'USED' && (
                      <div className="absolute inset-0 flex items-center justify-center">
                        <div className="border-2 border-[#FF3B30] text-[#FF3B30] font-bold text-xs px-3 py-1 rounded-lg -rotate-12 bg-white/95 shadow-md">
                          USED / 使用済み
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </div>
            ) : (
              <div className="text-xs text-slate-400">QRコード読み込み中…</div>
            )}
          </div>

          {/* Token String Preview */}
          <div className="mt-3 w-full bg-slate-50 rounded-lg p-2 text-left">
            <span className="text-[9.5px] text-[#8E8E93] block font-mono">TOKEN:</span>
            <span className="text-[10.5px] font-mono text-slate-800 break-all select-all font-semibold">
              {qrToken}
            </span>
          </div>

          {/* QR Action Button */}
          <div className="mt-2.5 w-full">
            {qrStatus === 'AVAILABLE' ? (
              <button
                onClick={handleUseQR}
                className="w-full py-2 px-3 rounded-xl bg-[#1C1C1E] text-white text-xs font-semibold hover:bg-black active:scale-98 transition-transform shadow-xs"
              >
                <span>QRコードを利用する (認証デモ)</span>
              </button>
            ) : (
              <div className="py-2 px-3 rounded-xl bg-slate-100 text-slate-500 text-xs font-medium text-center">
                このQRは既に使用済みです (二重利用防止)
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Footer Return Action */}
      <div className="w-full pt-3">
        <button
          onClick={onResetToNewChallenge}
          className="w-full py-3.5 px-4 rounded-xl bg-[#FF0033] text-white font-semibold text-sm hover:bg-[#E0002C] active:scale-98 transition-transform shadow-sm flex items-center justify-center gap-2"
        >
          <RotateCcw className="w-4 h-4 stroke-[2.5]" />
          <span>新しいチャレンジを作成する</span>
        </button>
      </div>
    </div>
  );
};
