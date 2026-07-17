import 'dart:math';

class NotePlacement {
  static final Random _random = Random();

  final double dx;
  final double dy;
  final double rotationDeg;
  final int colorIndex;

  const NotePlacement({
    required this.dx,
    required this.dy,
    required this.rotationDeg,
    required this.colorIndex,
  });

  factory NotePlacement.generate({required int colorCount}) {
    return NotePlacement(
      dx: (_random.nextDouble() * 2 - 1) * 0.55,
      dy: (_random.nextDouble() * 2 - 1) * 0.55,
      rotationDeg: (_random.nextDouble() * 2 - 1) * 5,
      colorIndex: _random.nextInt(colorCount),
    );
  }
}