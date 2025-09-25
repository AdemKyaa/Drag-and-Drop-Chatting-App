import 'package:flutter/material.dart';
import '../../models/box_item.dart';
import 'emoji_object.dart';

class ResizableEmojiBox extends StatelessWidget {
  final BoxItem box;
  final bool isEditing;
  final VoidCallback onUpdate;
  final VoidCallback onSave;
  final void Function(bool edit) onSelect;
  final VoidCallback onDelete;
  final bool Function(Offset) isOverTrash;
  final void Function(bool)? onDraggingOverTrash;

  const ResizableEmojiBox({
    super.key,
    required this.box,
    required this.isEditing,
    required this.onUpdate,
    required this.onSave,
    required this.onSelect,
    required this.onDelete,
    required this.isOverTrash,
    this.onDraggingOverTrash,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: box.position.dx,
      top: box.position.dy,
      child: GestureDetector(
        onTap: () => onSelect(true),
        onPanUpdate: (details) {
          box.position += details.delta;
          onUpdate();
        },
        onPanEnd: (_) => onSave(),
        child: EmojiObject(box: box),
      ),
    );
  }
}
