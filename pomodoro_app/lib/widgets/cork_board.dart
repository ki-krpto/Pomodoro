import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session.dart';
import '../services/subject_manager.dart';
import 'sticky_note.dart';
import 'cork_texture_painter.dart';

class CorkBoard extends StatelessWidget {
  final List<PomodoroSession> sessions;
  final int newestAnimatedIndex;

  const CorkBoard({
    super.key,
    required this.sessions,
    this.newestAnimatedIndex = -1,
  });

  static const double _framePadding = 18;
  static const double _gap = 8;

  Color _resolveColor(PomodoroSession s, SubjectManager sm) {
    if (s.subjectId == null) return kNoSubjectColor;
    final subject = sm.getSubject(s.subjectId);
    return subject?.color ?? kNoSubjectColor;
  }

  String? _resolveLabel(PomodoroSession s, SubjectManager sm) {
    if (s.subjectId == null) return null;
    final subject = sm.getSubject(s.subjectId);
    return subject?.name;
  }

  double _noteScale(int durationMinutes) {
    if (durationMinutes <= 15) return 0.70;
    if (durationMinutes <= 25) return 0.85;
    if (durationMinutes <= 45) return 1.0;
    if (durationMinutes <= 60) return 1.2;
    return 1.35;
  }

  @override
  Widget build(BuildContext context) {
    final subjectManager = context.watch<SubjectManager>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final boardWidth = constraints.maxWidth;
        final boardHeight = constraints.maxHeight;
        final corkWidth = boardWidth - _framePadding * 2;
        final corkHeight = boardHeight - _framePadding * 2;
        final noteSize = (corkWidth / 5).clamp(70.0, 120.0);

        final itemsPerRow =
            ((corkWidth + _gap) / (noteSize + _gap)).floor().clamp(1, 1 << 30);

        return Container(
          width: boardWidth,
          height: boardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CustomPaint(
              painter: WoodGrainPainter(baseColor: const Color(0xFF7A4E2C)),
              child: Padding(
                padding: const EdgeInsets.all(_framePadding),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CustomPaint(
                      painter: CorkTexturePainter(
                          baseColor: const Color(0xFFC49A5A)),
                      child: sessions.isEmpty
                          ? const _EmptyBoardHint()
                          : Stack(
                              clipBehavior: Clip.none,
                              children: [
                                for (var i = 0; i < sessions.length; i++)
                                  _positionedNote(
                                    i,
                                    noteSize,
                                    itemsPerRow,
                                    subjectManager,
                                    corkHeight,
                                  ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _positionedNote(
    int index,
    double noteSize,
    int itemsPerRow,
    SubjectManager subjectManager,
    double availableHeight,
  ) {
    final session = sessions[index];
    final col = index % itemsPerRow;
    final row = index ~/ itemsPerRow;

    final scale = _noteScale(session.durationMinutes);
    final scaledSize = noteSize * scale;
    final offset = (noteSize - scaledSize) / 2;

    return Positioned(
      left: col * (noteSize + _gap) + offset,
      top: row * (noteSize + _gap) + offset,
      child: StickyNote(
        session: session,
        size: scaledSize,
        animateIn: index == newestAnimatedIndex,
        subjectColor: _resolveColor(session, subjectManager),
        subjectLabel: _resolveLabel(session, subjectManager),
      ),
    );
  }
}

class _EmptyBoardHint extends StatelessWidget {
  const _EmptyBoardHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Your board is empty.\nFinish a focus session to pin your first note.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black.withOpacity(0.35),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
