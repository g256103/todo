import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/history/history_repository.dart';
import 'package:todo/features/home/home_page.dart';
import 'package:todo/features/points/point_repository.dart';
import 'package:todo/services/cashout_points_service.dart';
import 'package:todo/services/mock_payment_service.dart';
import 'package:todo/services/purchase_points_service.dart';

class _NoOpInvoker implements MockPaymentFunctionInvoker {
  @override
  Future<MockPaymentFunctionResponse> invoke(
    String functionName, {
    required Map<String, dynamic> body,
  }) async {
    return const MockPaymentFunctionResponse(statusCode: 500, data: null);
  }
}

class _FakePointRepository extends PointRepository {
  _FakePointRepository({this.points = 1500, this.transactions = const []});

  final int points;
  final List<PointTransactionItem> transactions;

  @override
  Future<int> fetchAvailablePoints() async => points;

  @override
  Future<List<PointTransactionItem>> fetchTransactions() async => transactions;

  @override
  Future<CashoutProgress> fetchCashoutProgress() async {
    return CashoutProgress(
      successCount: 4,
      firstSuccessAt: DateTime.utc(2026, 10, 1),
    );
  }
}

class _FakeHistoryRepository extends HistoryRepository {
  _FakeHistoryRepository({this.history = const []});

  final List<ChallengeHistoryItem> history;

  @override
  Future<List<ChallengeHistoryItem>> fetchHistory() async => history;
}

void main() {
  group('PointsPage', () {
    testWidgets('displays available points and details', (tester) async {
      final repo = _FakePointRepository(
        points: 2500,
        transactions: [
          PointTransactionItem(
            id: 'tx-1',
            type: 'GRANT',
            amount: 2500,
            createdAt: DateTime.utc(2026, 10, 1),
            expiresAt: DateTime.utc(2027, 1, 1),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PointsPage(
              repository: repo,
              purchaseService: PurchasePointsService(invoker: _NoOpInvoker()),
              cashoutService: CashoutPointsService(invoker: _NoOpInvoker()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('2500 pt'), findsOneWidget);
      expect(find.text('教育用途ポイント（有効期限3か月・譲渡不可）'), findsOneWidget);
      expect(find.text('現金化条件と進捗'), findsOneWidget);
      expect(find.text('4 / 7 回達成'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('チャレンジ失敗による付与'),
        200,
      );
      expect(find.text('+2500 pt'), findsOneWidget);
      expect(find.text('チャレンジ失敗による付与'), findsOneWidget);
    });
  });

  group('HistoryPage', () {
    testWidgets('displays empty state when no challenge history', (
      tester,
    ) async {
      final repo = _FakeHistoryRepository(history: const []);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HistoryPage(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('まだチャレンジ履歴がありません。'), findsOneWidget);
    });

    testWidgets('lists summary only; long-press opens snapshot detail', (
      tester,
    ) async {
      final item = ChallengeHistoryItem(
        id: 'c-1',
        amount: 1000,
        status: 'SUCCESS',
        createdAt: DateTime.utc(2026, 10, 5),
        deadline: DateTime.utc(2026, 10, 6),
        startedAt: DateTime.utc(2026, 10, 5, 1),
        finishedAt: DateTime.utc(2026, 10, 5, 2),
        tasks: const [
          ChallengeHistoryTask(
            id: 't-1',
            taskNameSnapshot: '完了済みタスク',
            status: 'COMPLETED',
          ),
          ChallengeHistoryTask(
            id: 't-2',
            taskNameSnapshot: '未完了タスク',
            status: 'INCOMPLETE',
          ),
        ],
      );
      final repo = _FakeHistoryRepository(history: [item]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HistoryPage(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('¥1000 コミット'), findsOneWidget);
      expect(find.text('SUCCESS'), findsOneWidget);
      expect(find.text('完了済みタスク'), findsNothing);
      expect(find.text('未完了タスク'), findsNothing);

      await tester.longPress(find.text('¥1000 コミット'));
      await tester.pumpAndSettle();

      expect(find.text('完了済みタスク'), findsOneWidget);
      expect(find.text('未完了タスク'), findsOneWidget);
      expect(find.text('閉じる'), findsOneWidget);
    });
  });
}
