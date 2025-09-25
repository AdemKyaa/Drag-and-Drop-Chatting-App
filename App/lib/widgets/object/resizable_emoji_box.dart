import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/box_item.dart';

class ResizableEmojiBox extends StatefulWidget {
  final BoxItem box;
  final bool isEditing;
  final VoidCallback onUpdate;
  final VoidCallback onSave;
  final void Function(bool edit) onSelect;
  final VoidCallback onDelete;
  final bool Function(Offset globalPos) isOverTrash;
  final void Function(bool)? onDraggingOverTrash;
  final void Function(bool)? onInteract;

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
    this.onInteract,
  });

  @override
  State<ResizableEmojiBox> createState() => _ResizableEmojiBoxState();
}

class _ResizableEmojiBoxState extends State<ResizableEmojiBox> {
  Offset? _dragStart;
  Offset? _startPos;

  void _handlePanStart(DragStartDetails details) {
    _dragStart = details.globalPosition;
    _startPos = widget.box.position;
    widget.onInteract?.call(true);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_dragStart == null || _startPos == null) return;

    final delta = details.globalPosition - _dragStart!;
    setState(() {
      widget.box.position = _startPos! + delta;
    });
    widget.onUpdate();

    // Çöp alanı kontrolü
    final overTrash = widget.isOverTrash(details.globalPosition);
    widget.onDraggingOverTrash?.call(overTrash);
  }

  void _handlePanEnd(DragEndDetails details) {
    widget.onSave();
    widget.onDraggingOverTrash?.call(false);

    final overTrash = widget.isOverTrash(_dragStart ?? Offset.zero);
    if (overTrash) {
      widget.onDelete();
    }
    _dragStart = null;
    _startPos = null;
    widget.onInteract?.call(false);
  }

  void _handleTap() {
    widget.onSelect(false); // seç ama edit mod değil
  }

  void _handleDoubleTap() {
    widget.onSelect(true); // edit panel aç
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.box;
    return Positioned(
      left: box.position.dx,
      top: box.position.dy,
      child: GestureDetector(
        onTap: _handleTap,
        onDoubleTap: _handleDoubleTap,
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        child: Transform.rotate(
          angle: box.rotation,
          child: Opacity(
            opacity: box.opacity,
            child: Container(
              decoration: box.isSelected
                  ? BoxDecoration(
                      border: Border.all(color: Colors.blueAccent, width: 2),
                    )
                  : null,
              padding: const EdgeInsets.all(4),
              child: Text(
                box.text ?? "😀",
                style: TextStyle(
                  fontSize: box.fontSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
