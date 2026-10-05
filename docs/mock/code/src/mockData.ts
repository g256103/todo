import { Task, Routine, HistoryItem, PointTransaction, UserProfile } from './types';

export const INITIAL_USER: UserProfile = {
  name: '山田 太郎',
  id: 'usr_84920412',
  email: 'taro.yamada@example.com',
  streakCount: 3, // days
  successCount: 4, // 4/7 toward cashout
  accessibleMode: false,
};

export const INITIAL_TASKS: Task[] = [
  { id: 'task-1', name: '英単語 30語暗記', category: '学習', createdAt: '2026-10-01' },
  { id: 'task-2', name: 'ストレッチ & 筋トレ 15分', category: '健康', createdAt: '2026-10-01' },
  { id: 'task-3', name: '技術書の読書 20ページ', category: '自己研鑽', createdAt: '2026-10-02' },
  { id: 'task-4', name: 'コードレビュー 2件実施', category: '仕事', createdAt: '2026-10-03' },
  { id: 'task-5', name: '部屋のクイック片付け 10分', category: '生活', createdAt: '2026-10-03' },
];

export const INITIAL_ROUTINES: Routine[] = [
  {
    id: 'routine-1',
    name: '朝の集中ルーティーン',
    taskIds: ['task-1', 'task-2', 'task-3'],
    createdAt: '2026-10-01',
  },
  {
    id: 'routine-2',
    name: '夜の自己投資パック',
    taskIds: ['task-3', 'task-4'],
    createdAt: '2026-10-02',
  },
];

export const INITIAL_HISTORY: HistoryItem[] = [
  {
    id: 'hist-1',
    date: '2026-10-03 21:00',
    amount: 1000,
    status: 'SUCCESS',
    refundAmount: 1000,
    tasks: [
      { name: '英単語 30語暗記', completed: true },
      { name: 'ストレッチ & 筋トレ 15分', completed: true },
      { name: '技術書の読書 20ページ', completed: true },
    ],
  },
  {
    id: 'hist-2',
    date: '2026-10-02 20:30',
    amount: 500,
    status: 'FAILED',
    pointsAwarded: 500,
    tasks: [
      { name: 'コードレビュー 2件実施', completed: true },
      { name: '部屋のクイック片付け 10分', completed: false },
    ],
  },
  {
    id: 'hist-3',
    date: '2026-10-01 19:00',
    amount: 2000,
    status: 'SUCCESS',
    refundAmount: 2000,
    tasks: [
      { name: '英単語 30語暗記', completed: true },
      { name: '技術書の読書 20ページ', completed: true },
    ],
  },
  {
    id: 'hist-4',
    date: '2026-09-29 22:00',
    amount: 1500,
    status: 'SUCCESS',
    refundAmount: 1500,
    tasks: [
      { name: 'ストレッチ & 筋トレ 15分', completed: true },
      { name: '部屋のクイック片付け 10分', completed: true },
    ],
  },
];

export const INITIAL_POINT_TRANSACTIONS: PointTransaction[] = [
  {
    id: 'pt-1',
    title: '未完了チャレンジ補償 (2026-10-02)',
    amount: 500,
    type: 'AWARD_FAILED_CHALLENGE',
    date: '2026-10-02',
    expiresAt: '2027-01-02',
  },
  {
    id: 'pt-2',
    title: '未完了チャレンジ補償 (2026-09-25)',
    amount: 700,
    type: 'AWARD_FAILED_CHALLENGE',
    date: '2026-09-25',
    expiresAt: '2026-12-25',
  },
];

export const EXCHANGE_ITEMS = [
  {
    id: 'item-1',
    title: 'IT・プログラミング技術書 引換クーポン',
    category: '書籍',
    points: 1500,
    description: '対象の電子書籍ストア・書店で使える技術書専用クーポン',
  },
  {
    id: 'item-2',
    title: 'オンライン学習プラットフォーム 1ヶ月受講券',
    category: '学習教材',
    points: 2000,
    description: 'プログラミング、ビジネススキル動画が見放題',
  },
  {
    id: 'item-3',
    title: '国家資格・検定試験 対策問題集',
    category: '資格教材',
    points: 1200,
    description: '厳選された実践問題集と解説PDFセット',
  },
];
