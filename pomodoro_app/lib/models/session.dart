/// A single completed Pomodoro. Everything needed to render its sticky
/// note is captured here at creation time, including the note's
/// permanent visual "personality" (jitter, rotation, color) — so the
/// board never has to recompute or move a note after it's been placed.
class PomodoroSession {
  final int durationMinutes;
  final DateTime completedAt;

  /// Permanent jitter within the note's grid cell, each in [-1, 1].
  final double dx;
  final double dy;

  /// Permanent rotation in degrees, roughly [-5, 5].
  final double rotationDeg;

  /// Permanent index into the sticky note color palette.
  final int colorIndex;

  /// Optional subject tag assigned at creation time.
  final String? subjectId;

  const PomodoroSession({
    required this.durationMinutes,
    required this.completedAt,
    required this.dx,
    required this.dy,
    required this.rotationDeg,
    required this.colorIndex,
    this.subjectId,
  });

  Map<String, dynamic> toJson() => {
        'durationMinutes': durationMinutes,
        'completedAt': completedAt.toIso8601String(),
        'dx': dx,
        'dy': dy,
        'rotationDeg': rotationDeg,
        'colorIndex': colorIndex,
        if (subjectId != null) 'subjectId': subjectId,
      };

  factory PomodoroSession.fromJson(Map<String, dynamic> json) {
    return PomodoroSession(
      durationMinutes: json['durationMinutes'] as int,
      completedAt: DateTime.parse(json['completedAt'] as String),
      dx: (json['dx'] as num).toDouble(),
      dy: (json['dy'] as num).toDouble(),
      rotationDeg: (json['rotationDeg'] as num).toDouble(),
      colorIndex: json['colorIndex'] as int,
      subjectId: json['subjectId'] as String?,
    );
  }
}
