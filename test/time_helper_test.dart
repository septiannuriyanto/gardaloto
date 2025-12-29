import 'package:flutter_test/flutter_test.dart';
import 'package:gardaloto/core/time_helper.dart';

void main() {
  test('TimeHelper.now() returns time in UTC+8 (Asia/Makassar)', () {
    // We expect the hours to be shifted by roughly 8 hours from real UTC
    // But since TimeHelper.now() returns a "fake local" which is just UTC+8 added to UTC time,
    // the value itself should be (RealUTC + 8h).
    // Let's compare timestamps.

    // Actually, TimeHelper returns: DateTime.now().toUtc().add(Duration(hours: 8));
    // So if real UTC is 10:00, TimeHelper returns 18:00.

    // Verification:
    // Get real UTC
    final realUtc = DateTime.now().toUtc();
    // Get TimeHelper time
    final makassarTime = TimeHelper.now();

    // Check difference. makassarTime should be ahead of realUtc by roughly 8 hours.
    // Allow small delta for execution time.
    final diff = makassarTime.difference(realUtc);

    expect(diff.inHours, 8);
    // Tolerance for minutes/seconds is not needed if we check difference of "Value"
    // Wait, difference() compares absolute moments if they are both UTC?
    // TimeHelper.now() returns a DateTime in UTC timezone.
    // realUtc returns a DateTime in UTC timezone.
    // So difference() will compute the difference in their millisecondsSinceEpoch.
    // Since TimeHelper added 8 hours to the Value, the difference should be 8 hours.
  });
}
