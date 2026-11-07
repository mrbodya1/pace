class XpProgress {
  const XpProgress(this.xp);

  final int xp;

  int get level {
    if (xp >= 65000) return 10;
    if (xp >= 48000) return 9;
    if (xp >= 34000) return 8;
    if (xp >= 23000) return 7;
    if (xp >= 15000) return 6;
    if (xp >= 9000) return 5;
    if (xp >= 5000) return 4;
    if (xp >= 2500) return 3;
    if (xp >= 1000) return 2;
    return 1;
  }

  int get levelStart {
    const levels = [
      0, 1000, 2500, 5000, 9000,
      15000, 23000, 34000, 48000, 65000,
    ];
    return levels[level - 1];
  }

  int get levelEnd {
    const levels = [
      1000, 2500, 5000, 9000, 15000,
      23000, 34000, 48000, 65000, 85000,
    ];
    return levels[level - 1];
  }
}
