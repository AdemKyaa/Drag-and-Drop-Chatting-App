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
    const double s = 16;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: -s / 2,
          bottom: -s / 2,
          child: GestureDetector(
            onPanUpdate: (d) {
              box.width = (box.width + d.delta.dx).clamp(50, 2000);
              box.height = (box.height + d.delta.dy).clamp(50, 2000);
              onUpdate();
            },
            onPanEnd: (_) => onSave(),
            child: Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
