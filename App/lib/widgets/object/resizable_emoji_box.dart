import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/box_item.dart';

class ResizableEmojiBox extends StatefulWidget {
  final BoxItem box;
  final bool isEditing;
  final VoidCallback onUpdate;
  final Future<void> Function() onSave;
  final void Function(bool edit) onSelect;
  final Future<void> Function() onDelete;
  final bool Function(Offset) isOverTrash;
  final void Function(bool)? onDraggingOverTrash;
  final void Function(BoxItem box, int pointerId, Offset globalPos)? onPrimaryPointerDown;
  final VoidCallback? onBringToFront;
  final VoidCallback? onSendToBack;

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
    this.onPrimaryPointerDown,
    this.onBringToFront,
    this.onSendToBack,
  });

  @override
  State<ResizableEmojiBox> createState() => _ResizableEmojiBoxState();
}

class _ResizableEmojiBoxState extends State<ResizableEmojiBox> {
  Offset? _dragStart;

  @override
  Widget build(BuildContext context) {
    final b = widget.box;

    return Positioned(
      left: b.position.dx,
      top: b.position.dy,
      child: GestureDetector(
        onTap: () => widget.onSelect(false),
        onDoubleTap: () => widget.onSelect(true),
        onPanStart: (details) {
          _dragStart = details.globalPosition;
          widget.onSelect(false);
          widget.onPrimaryPointerDown?.call(widget.box, 0, details.globalPosition);
        },
        onPanUpdate: (details) {
          final start = _dragStart;
          if (start == null) return;
          final delta = details.globalPosition - start;
          _dragStart = details.globalPosition;
          setState(() {
            b.position += delta;
          });

          // Çöp alanı kontrol
          final overTrash = widget.isOverTrash(details.globalPosition);
          widget.onDraggingOverTrash?.call(overTrash);
        },
        onPanEnd: (_) async {
          final overTrash = widget.isOverTrash(
            b.position + Offset(b.width / 2, b.height / 2),
          );
          if (overTrash) {
            await widget.onDelete();
          } else {
            await widget.onSave();
          }
          widget.onDraggingOverTrash?.call(false);
        },
        child: Transform.rotate(
          angle: b.rotation,
          child: Opacity(
            opacity: b.opacity,
            child: Text(
              b.text ?? "😀",
              style: TextStyle(
                fontSize: b.fixedFontSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
