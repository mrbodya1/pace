/// Accumulates ascents with a 3 m deadband; small oscillations do not add gain.
class ElevationTracker {
  double? _anchor;
  double gain = 0;

  void add(double altitude) {
    if (!altitude.isFinite) return;
    final previous = _anchor;
    if (previous == null) {
      _anchor = altitude;
      return;
    }
    final delta = altitude - previous;
    if (delta >= 3) {
      gain += delta;
      _anchor = altitude;
    } else if (delta <= -3) {
      _anchor = altitude;
    }
  }

  void resetAnchor() => _anchor = null;
  void reset() {
    gain = 0;
    resetAnchor();
  }
}
