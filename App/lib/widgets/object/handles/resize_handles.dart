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
    const double p = 16; // handle boyutu
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 🔵 Sol-Üst
        Positioned(
          left: -s / 2 + p,
          top: -s / 2 + p,
          child: _buildHandle((d) {
            box.width = (box.width - d.delta.dx).clamp(32, 4096);
            box.height = (box.height - d.delta.dy).clamp(32, 4096);
            box.position += d.delta; // sola/üstte kaydırınca pozisyonu da düzelt
            onUpdate();
          }),
        ),

        // 🔵 Üst-Orta
        Positioned(
          left: box.width / 2 - s / 2,
          top: -s / 2 + p,
          child: _buildHandle((d) {
            box.height = (box.height - d.delta.dy).clamp(32, 4096);
            box.position += Offset(0, d.delta.dy);
            onUpdate();
          }),
        ),

        // 🔵 Sağ-Üst
        Positioned(
          right: -s / 2 + p,
          top: -s / 2 + p,
          child: _buildHandle((d) {
            box.width = (box.width + d.delta.dx).clamp(32, 4096);
            box.height = (box.height - d.delta.dy).clamp(32, 4096);
            box.position += Offset(0, d.delta.dy);
            onUpdate();
          }),
        ),

        // 🔵 Sol-Orta
        Positioned(
          left: -s / 2 + p,
          top: box.height / 2 - s / 2,
          child: _buildHandle((d) {
            box.width = (box.width - d.delta.dx).clamp(32, 4096);
            box.position += Offset(d.delta.dx, 0);
            onUpdate();
          }),
        ),

        // 🔵 Sağ-Orta
        Positioned(
          right: -s / 2 + p,
          top: box.height / 2 - s / 2,
          child: _buildHandle((d) {
            box.width = (box.width + d.delta.dx).clamp(32, 4096);
            onUpdate();
          }),
        ),

        // 🔵 Sol-Alt
        Positioned(
          left: -s / 2 + p,
          bottom: -s / 2 + p,
          child: _buildHandle((d) {
            box.width = (box.width - d.delta.dx).clamp(32, 4096);
            box.height = (box.height + d.delta.dy).clamp(32, 4096);
            box.position += Offset(d.delta.dx, 0);
            onUpdate();
          }),
        ),

        // 🔵 Alt-Orta
        Positioned(
          left: box.width / 2 - s / 2,
          bottom: -s / 2 + p,
          child: _buildHandle((d) {
            box.height = (box.height + d.delta.dy).clamp(32, 4096);
            onUpdate();
          }),
        ),

        // 🔵 Sağ-Alt
        Positioned(
          right: -s / 2 + p,
          bottom: -s / 2 + p,
          child: _buildHandle((d) {
            box.width = (box.width + d.delta.dx).clamp(32, 4096);
            box.height = (box.height + d.delta.dy).clamp(32, 4096);
            onUpdate();
          }),
        ),
      ],
    );
  }

  Widget _buildHandle(void Function(DragUpdateDetails) onDrag) {
    const double s = 16;
    return GestureDetector(
      onPanUpdate: onDrag,
      onPanEnd: (_) => onSave(),
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
