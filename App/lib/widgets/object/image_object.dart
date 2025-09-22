// lib/widgets/object/image_object.dart
import 'package:flutter/material.dart';
import '../../models/box_item.dart';

class ImageObject extends StatefulWidget {
  final BoxItem box;
  final bool isEditing;
  final VoidCallback onUpdate;
  final VoidCallback onSave;
  final void Function(bool edit) onSelect;
  final VoidCallback onDelete;
  final bool Function(Offset) isOverTrash;
  final void Function(bool)? onDraggingOverTrash;
  final void Function(bool)? onInteract;

  const ImageObject({
    super.key,
    required this.box,
    required this.isEditing,
    required this.onUpdate,
    required this.onSave,
    required this.onSelect,
    required this.onDelete,
    required this.isOverTrash,
    this.onDraggingOverTrash,
    this.onInteract,
  });

  @override
  State<ImageObject> createState() => _ImageObjectState();
}

class _ImageObjectState extends State<ImageObject> {
  void _onScaleUpdate(ScaleUpdateDetails d) {
    final b = widget.box;
    if (d.pointerCount == 1) {
      b.position += d.focalPointDelta;
    } else if (d.pointerCount >= 2) {
      b.width = (b.width * d.scale).clamp(50, 2000);
      b.height = (b.height * d.scale).clamp(50, 2000);
      b.rotation += d.rotation;
    }
    widget.onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.box;
    return Positioned(
      left: b.position.dx,
      top: b.position.dy,
      child: GestureDetector(
        onScaleUpdate: _onScaleUpdate,
        onTap: () {
          widget.onSelect(true);
        },
        onDoubleTap: () => widget.onDelete(),
        child: Transform.rotate(
          angle: b.rotation,
          child: Container(
            width: b.width,
            height: b.height,
            decoration: BoxDecoration(
              border: Border.all(
                color: b.isSelected ? Colors.blue : Colors.transparent,
                width: 2,
              ),
            ),
            child: b.imageBytes == null
                ? const Center(child: Text("📷 Resim Yok"))
                : Image.memory(b.imageBytes!, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}
