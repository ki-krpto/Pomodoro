import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/session.dart';

/// Warm, muted palette — deliberately desaturated so the board reads
/// as a desk, not a game board.
const List<Color> kStickyNoteColors = [
  Color(0xFFF4D35E), // butter yellow
  Color(0xFFA8C69F), // sage green
  Color(0xFF8FAFC4), // dusty blue
  Color(0xFFD9A5A0), // dusty rose
  Color(0xFFB79FC4), // muted plum
];

/// Neutral colour used when a note has no subject assigned.
const Color kNoSubjectColor = Color(0xFFFFF3CD);

class StickyNote extends StatefulWidget {
  final PomodoroSession session;
  final double size;

  /// Only true for the note that was just created — everything else
  /// renders instantly at full opacity, no re-animation on rebuild.
  final bool animateIn;

  /// If non-null this overrides the palette-based / neutral colour so
  /// the note reflects its subject's colour.
  final Color? subjectColor;

  /// The subject name to display on the note, or null to hide it.
  final String? subjectLabel;

  const StickyNote({
    super.key,
    required this.session,
    this.size = 84,
    this.animateIn = false,
    this.subjectColor,
    this.subjectLabel,
  });

  @override
  State<StickyNote> createState() => _StickyNoteState();
}

class _StickyNoteState extends State<StickyNote>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    if (widget.animateIn) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _timeLabel {
    final t = widget.session.completedAt;
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.subjectColor ??
        kStickyNoteColors[widget.session.colorIndex % kStickyNoteColors.length];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(scale: _scale.value, child: child),
        );
      },
      child: Transform.rotate(
        angle: widget.session.rotationDeg * (math.pi / 180),
        child: Container(
          width: widget.size,
          height: widget.size,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${widget.session.durationMinutes}m',
                style: GoogleFonts.patrickHand(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3A2E27),
                ),
              ),
              if (widget.subjectLabel != null) ...[
                const SizedBox(height: 1),
                Text(
                  widget.subjectLabel!,
                  style: GoogleFonts.patrickHand(
                    fontSize: 12,
                    color: const Color(0xFF3A2E27).withOpacity(0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
              const SizedBox(height: 2),
              Text(
                _timeLabel,
                style: GoogleFonts.patrickHand(
                  fontSize: 13,
                  color: const Color(0xFF3A2E27).withOpacity(0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}