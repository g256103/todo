export type TabType = 'main' | 'points' | 'settings' | 'history' | 'edit';

export type ChallengeStatus = 'WAITING' | 'IN_PROGRESS' | 'SUCCESS' | 'FAILED';

export type TaskStatus = 'INCOMPLETE' | 'COMPLETED';

export interface Task {
  id: string;
  name: string;
  category?: string;
  createdAt: string;
}

export interface Routine {
  id: string;
  name: string;
  taskIds: string[];
  createdAt: string;
}

export interface ChallengeTask {
  id: string;
  taskId: string;
  taskNameSnapshot: string;
  status: TaskStatus;
  completedAt?: string;
}

export interface Challenge {
  id: string;
  paymentId: string;
  amount: number; // 100 - 5000 yen (integer)
  status: ChallengeStatus;
  createdAt: string;
  autoStartAt: string; // 5 minutes after payment
  startedAt?: string;
  deadline: string; // Absolute ISO string
  finishedAt?: string;
  tasks: ChallengeTask[];
  qrToken?: string;
  qrStatus?: 'AVAILABLE' | 'USED';
  pointsAwarded?: number;
}

export interface HistoryItem {
  id: string;
  date: string;
  amount: number;
  status: 'SUCCESS' | 'FAILED';
  tasks: {
    name: string;
    completed: boolean;
  }[];
  refundAmount?: number;
  pointsAwarded?: number;
}

export interface PointTransaction {
  id: string;
  title: string;
  amount: number; // positive or negative
  type: 'AWARD_FAILED_CHALLENGE' | 'EXCHANGE' | 'CASHOUT';
  date: string;
  expiresAt: string; // 3 months
}

export interface UserProfile {
  name: string;
  id: string;
  email: string;
  streakCount: number; // consecutive weeks
  successCount: number; // completed challenges
  accessibleMode: boolean; // Screen reader / alternate dialog mode
}
