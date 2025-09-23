import 'package:flutter/material.dart';

class OutlinePainter extends CustomPainter {
  final double radius;
  final bool show;
  final Color color;
  final double strokeWidth;

  OutlinePainter({
    required this.radius,
    required this.show,
    required this.color,
    this.strokeWidth = 2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!show) return;
    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(radius * (size.width < size.height ? size.width : size.height)),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(OutlinePainter old) =>
      old.radius != radius ||
      old.show != show ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}