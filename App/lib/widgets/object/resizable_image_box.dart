import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/box_item.dart';

class ResizableImageBox extends StatefulWidget {
  final BoxItem box;
  final bool isEditing;
  final VoidCallback onUpdate;
  final VoidCallback onSave;
  final void Function(bool edit) onSelect;
  final VoidCallback onDelete;
  final bool Function(Offset) isOverTrash;
  final void Function(bool)? onDraggingOverTrash;
  final void Function(bool)? onInteract;

  const ResizableImageBox({
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
  State<ResizableImageBox> createState() => _ResizableImageBoxState();
}

class _ResizableImageBoxState extends State<ResizableImageBox> {
  late Offset position;
  late double width;
  late double height;
  bool dragging = false;

  @override
  void initState() {
    super.initState();
    position = widget.box.position;
    width = widget.box.width;
    height = widget.box.height;
  }

  void _updatePosition(Offset delta) {
    setState(() {
      position += delta;
    });
    widget.box.position = position;
    widget.onUpdate();
  }

  void _updateSize(Offset delta) {
    setState(() {
      width = (width + delta.dx).clamp(50, 600);
      height = (height + delta.dy).clamp(50, 600);
    });
    widget.box.width = width;
    widget.box.height = height;
    widget.onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onTap: () => widget.onSelect(true),
        onPanStart: (_) {
          setState(() => dragging = true);
          widget.onInteract?.call(true);
        },
        onPanUpdate: (details) {
          _updatePosition(details.delta);
          if (widget.isOverTrash(details.globalPosition)) {
            widget.onDraggingOverTrash?.call(true);
          } else {
            widget.onDraggingOverTrash?.call(false);
          }
        },
        onPanEnd: (_) {
          setState(() => dragging = false);
          widget.onInteract?.call(false);

          if (widget.isOverTrash(position)) {
            widget.onDelete();
          } else {
            widget.onSave();
          }
          widget.onDraggingOverTrash?.call(false);
        },
        child: Stack(
          children: [
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                border: widget.box.isSelected && widget.isEditing
                    ? Border.all(color: Colors.blue, width: 2)
                    : null,
              ),
              child: widget.box.imageBytes != null &&
                      widget.box.imageBytes!.isNotEmpty
                  ? Image.memory(
                      widget.box.imageBytes as Uint8List,
                      fit: BoxFit.cover,
                    )
                  : const ColoredBox(color: Colors.grey),
            ),

            // 🔲 Sağ-alt köşe resize handle
            if (widget.isEditing && widget.box.isSelected)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanUpdate: (details) => _updateSize(details.delta),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black),
                    ),
                    child: const Icon(Icons.drag_handle, size: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
