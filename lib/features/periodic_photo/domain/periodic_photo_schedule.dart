/// Persisted timing state for the periodic photo requirement.
///
/// Kept on disk (not only in memory) so a Flutter restart, a process kill or a
/// background/foreground cycle never restarts the full interval. A photo
/// captured at 10:00 with a 1 minute interval is due at 10:01 even if the app
/// is relaunched at 10:00:30.
class PeriodicPhotoSchedule {
  const PeriodicPhotoSchedule({
    this.lastPeriodicPhotoAt,
    this.nextPhotoDueAt,
    this.intervalMinutes,
  });

  /// When the last requirement was validly completed, or `null` yet.
  final DateTime? lastPeriodicPhotoAt;

  /// Absolute deadline of the current requirement, or `null` when never
  /// scheduled.
  final DateTime? nextPhotoDueAt;

  /// The interval that produced [nextPhotoDueAt], so a later configuration
  /// change can be detected and the schedule recomputed cleanly.
  final int? intervalMinutes;

  bool get hasDeadline => nextPhotoDueAt != null;

  /// Whether [deadline] has been reached relative to [now].
  bool isDueAt(DateTime now) {
    final deadline = nextPhotoDueAt;
    return deadline != null && !now.isBefore(deadline);
  }

  PeriodicPhotoSchedule copyWith({
    DateTime? lastPeriodicPhotoAt,
    DateTime? nextPhotoDueAt,
    int? intervalMinutes,
  }) => PeriodicPhotoSchedule(
    lastPeriodicPhotoAt: lastPeriodicPhotoAt ?? this.lastPeriodicPhotoAt,
    nextPhotoDueAt: nextPhotoDueAt ?? this.nextPhotoDueAt,
    intervalMinutes: intervalMinutes ?? this.intervalMinutes,
  );

  Map<String, Object?> toJson() => {
    'lastPeriodicPhotoAt': lastPeriodicPhotoAt?.toIso8601String(),
    'nextPhotoDueAt': nextPhotoDueAt?.toIso8601String(),
    'intervalMinutes': intervalMinutes,
  };

  factory PeriodicPhotoSchedule.fromJson(Map<String, dynamic> json) =>
      PeriodicPhotoSchedule(
        lastPeriodicPhotoAt: _parseDate(json['lastPeriodicPhotoAt']),
        nextPhotoDueAt: _parseDate(json['nextPhotoDueAt']),
        intervalMinutes: json['intervalMinutes'] is int
            ? json['intervalMinutes'] as int
            : null,
      );
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
