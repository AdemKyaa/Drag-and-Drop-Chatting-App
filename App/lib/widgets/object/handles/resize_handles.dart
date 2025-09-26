import 'package:flutter/material.dart';
import '../../../models/box_item.dart';

class ResizeHandles extends StatelessWidget {
  final BoxItem box;
  final VoidCallback onUpdate;
  final VoidCallback onSave;

  const ResizeHandles({
    super.key,
    required this.box,
    required this.onUpdate,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    const double s = 32; // handle boyutu
    const double p = 24; // handle boyutu
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 🔵 Üst-Ort
        Positioned(
          left: box.width / 2 - s / 2 - 8,
          top: -s / 2 + p,
          child: _buildHandle((d) {
            box.height = (box.height - d.delta.dy).clamp(32, 4096);
            box.position += Offset(0, d.delta.dy);
            onUpdate();
          }),
        ),

        // 🔵 Sol-Orta
        Positioned(
          left: -s / 2 + p,
          top: box.height / 2 - s / 2 - 8,
          child: _buildHandle((d) {
            box.width = (box.width - d.delta.dx).clamp(32, 4096);
            box.position += Offset(d.delta.dx, 0);
            onUpdate();
          }, vertical: true),
        ),

        // 🔵 Sağ-Orta
        Positioned(
          right: -s / 2 + p,
          top: box.height / 2 - s / 2 - 8,
          child: _buildHandle((d) {
            box.width = (box.width + d.delta.dx).clamp(32, 4096);
            onUpdate();
          }, vertical: true),
        ),

        // 🔵 Alt-Orta
        Positioned(
          left: box.width / 2 - s / 2 - 8,
          bottom: -s / 2 + p,
          child: _buildHandle((d) {
            box.height = (box.height + d.delta.dy).clamp(32, 4096);
            onUpdate();
          }),
        ),
      ],
    );
  }

  Widget _buildHandle(
    void Function(DragUpdateDetails) onDrag, {
    bool vertical = false, // sağ/sol için true
  }) {
    const double longSide = 48;
    const double shortSide = 12;

    final child = Container(
      width: vertical ? shortSide : longSide,
      height: vertical ? longSide : shortSide,
      decoration: BoxDecoration(
        color: const Color.fromARGB(125, 33, 149, 243),
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return GestureDetector(
      onPanUpdate: onDrag,
      onPanEnd: (_) => onSave(),
      child: child,
    );
  }
}
