import React from 'react';
import { AlertCircle, CheckCircle2, X } from 'lucide-react';

export interface SnackbarMessage {
  id: string;
  type: 'error' | 'success' | 'info';
  text: string;
}

interface SnackbarProps {
  message: SnackbarMessage | null;
  onClose: () => void;
}

export const Snackbar: React.FC<SnackbarProps> = ({ message, onClose }) => {
  if (!message) return null;

  return (
    <div className="absolute top-14 left-4 right-4 z-50 transition-all duration-200 animate-in fade-in slide-in-from-top-2">
      <div
        className={`w-full p-3 rounded-xl shadow-lg border flex items-center justify-between text-xs font-medium ${
          message.type === 'error'
            ? 'bg-[#1C1C1E] text-white border-red-500/40'
            : message.type === 'success'
            ? 'bg-[#34C759] text-white border-emerald-400'
            : 'bg-white text-slate-800 border-slate-200'
        }`}
      >
        <div className="flex items-center gap-2">
          {message.type === 'error' && <AlertCircle className="w-4 h-4 text-[#FF3B30] shrink-0" />}
          {message.type === 'success' && <CheckCircle2 className="w-4 h-4 text-white shrink-0" />}
          <span>{message.text}</span>
        </div>
        <button
          onClick={onClose}
          className="p-1 rounded-md hover:bg-white/20 transition-colors ml-2"
        >
          <X className="w-3.5 h-3.5" />
        </button>
      </div>
    </div>
  );
};
