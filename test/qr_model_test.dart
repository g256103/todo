import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/qr/qr_model.dart';
import 'package:todo/features/qr/qr_payloads.dart';

void main() {
  test('preview payload uses lowercase challenge id', () {
    expect(
      buildPreviewQrPayload('AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE'),
      'https://paypay-commit.mock/preview?challenge_id=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    );
  });

  test('extractClaimTokenFromQrContent accepts claim URL only', () {
    expect(
      extractClaimTokenFromQrContent(
        'https://paypay-commit.mock/claim?token=abc%2F123&amount=1000&status=VERIFIED',
      ),
      'abc/123',
    );
    expect(
      extractClaimTokenFromQrContent(
        'https://paypay-commit.mock/preview?challenge_id=x',
      ),
      isNull,
    );
  });

  test('generateQrModel assigns finder cells to last task', () {
    const challengeId = '22222222-2222-4222-8222-222222222222';
    final model = generatePreviewQrModel(challengeId, 3);
    final lastTaskCells = model.cells.where((c) => c.taskIndex == 2);
    expect(lastTaskCells.any((c) => c.isFinder), isTrue);
    for (final cell in model.cells.where((c) => c.isFinder)) {
      expect(cell.taskIndex, 2);
    }
  });

  test('generateQrModel is deterministic for fixed seed', () {
    const id = '22222222-2222-4222-8222-222222222222';
    final a = generatePreviewQrModel(id, 2);
    final b = generatePreviewQrModel(id, 2);
    expect(a.cells.length, b.cells.length);
    for (var i = 0; i < a.cells.length; i++) {
      expect(a.cells[i].row, b.cells[i].row);
      expect(a.cells[i].col, b.cells[i].col);
      expect(a.cells[i].taskIndex, b.cells[i].taskIndex);
    }
  });
}
