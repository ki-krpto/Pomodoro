import 'dart:math';
import 'package:flutter/material.dart';

class CorkTexturePainter extends CustomPainter {
  final Color baseColor;

  CorkTexturePainter({required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = baseColor);

    final random = Random(42);
    final speckle = Paint()..style = PaintingStyle.fill;

    final speckleCount = (size.width * size.height / 900).round();
    for (var i = 0; i < speckleCount; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final radius = 0.6 + random.nextDouble() * 1.6;
      final darken = random.nextBool();
      speckle.color = (darken ? Colors.black : Colors.white)
          .withOpacity(0.035 + random.nextDouble() * 0.05);
      canvas.drawCircle(Offset(dx, dy), radius, speckle);
    }
  }

  @override
  bool shouldRepaint(covariant CorkTexturePainter oldDelegate) =>
      oldDelegate.baseColor != baseColor;
}

class WoodGrainPainter extends CustomPainter {
  final Color baseColor;

  WoodGrainPainter({required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = baseColor);

    final random = Random(7);
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final lineCount = (size.height / 6).round().clamp(1, 200);
    for (var i = 0; i < lineCount; i++) {
      final y = random.nextDouble() * size.height;
      grain.color =
          Colors.black.withOpacity(0.05 + random.nextDouble() * 0.05);
      final path = Path()..moveTo(0, y);
      const segments = 4;
      for (var s = 1; s <= segments; s++) {
        final x = size.width * s / segments;
        final wobble = (random.nextDouble() - 0.5) * 6;
        path.lineTo(x, y + wobble);
      }
      canvas.drawPath(path, grain);
    }
  }

  @override
  bool shouldRepaint(covariant WoodGrainPainter oldDelegate) =>
      oldDelegate.baseColor != baseColor;
}