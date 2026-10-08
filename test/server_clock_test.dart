import 'package:flutter_test/flutter_test.dart';
import 'package:todo/services/server_clock.dart';

void main() {
  test('reset clears offset and last sync', () {
    final clock = ServerClock();
    clock.reset();
    expect(clock.offset, Duration.zero);
    expect(clock.lastSyncedAt, isNull);
  });
}
