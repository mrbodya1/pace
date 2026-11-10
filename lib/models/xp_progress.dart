/// Levels are derived from total XP; no level is stored or migrated.
class XpProgress {
  const XpProgress(this.xp);
  final int xp;
  static const _initial = [
    0,
    1000,
    2500,
    5000,
    9000,
    15000,
    23000,
    34000,
    48000,
    65000,
  ];
  int get _balance => xp < 0 ? 0 : xp;

  /// Preserve levels 1–10, then continue the existing 20k, 23k, 26k… gaps.
  static int xpForLevel(int level) {
    if (level < 1) {
      throw ArgumentError.value(level, 'level', 'Must be positive');
    }
    if (level <= _initial.length) return _initial[level - 1];
    final steps = level - 10;
    return 65000 + steps * 20000 + (steps * (steps - 1) ~/ 2) * 3000;
  }

  int get level {
    if (_balance < _initial.last) {
      for (var i = _initial.length - 1; i >= 0; i--) {
        if (_balance >= _initial[i]) return i + 1;
      }
    }
    // Exponential bounds and binary search keep large imported balances cheap.
    var low = 10, high = 11;
    while (xpForLevel(high) <= _balance) {
      low = high;
      high = 10 + (high - 10) * 2;
    }
    while (high - low > 1) {
      final middle = low + (high - low) ~/ 2;
      if (xpForLevel(middle) <= _balance) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return low;
  }

  int get levelStart => xpForLevel(level);
  int get levelEnd => xpForLevel(level + 1);
  int get earnedInLevel => _balance - levelStart;
  int get remaining => levelEnd - _balance;
  double get fraction =>
      (earnedInLevel / (levelEnd - levelStart)).clamp(0.0, 1.0).toDouble();
}
