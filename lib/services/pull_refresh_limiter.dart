class PullRefreshLimiter {
  PullRefreshLimiter({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static final home = PullRefreshLimiter();
  final DateTime Function() _now;
  final List<DateTime> _refreshes = [];

  bool tryAcquire() {
    final now = _now();
    _refreshes.removeWhere(
      (time) => now.difference(time) >= const Duration(minutes: 1),
    );
    if (_refreshes.length >= 2) return false;
    _refreshes.add(now);
    return true;
  }
}
