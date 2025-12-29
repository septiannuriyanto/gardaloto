class TimeHelper {
  /// Returns the current time in Asia/Makassar timezone (UTC+8).
  static DateTime now() {
    // Current UTC time + 8 hours
    return DateTime.now().toUtc().add(const Duration(hours: 8));
  }
}
