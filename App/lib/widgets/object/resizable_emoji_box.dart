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
  final void Function(bool active)? onInteract;

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
    this.onInteract,
  });

  @override
  State<ResizableEmojiBox> createState() => _ResizableEmojiBoxState();
}

class _ResizableEmojiBoxState extends State<ResizableEmojiBox> {
  Offset? _dragStart;
  Offset? _lastGlobalPos; // <— drop anında çöp kontrolü için

  @override
  Widget build(BuildContext context) {
    final b = widget.box;

    return Positioned(
      left: b.position.dx,
      top: b.position.dy,
      child: GestureDetector(
        onTap: () => widget.onSelect(true),
        onLongPress: () {
          setState(() {
            b.isSelected = true;
            b.scale = 1.2;       // 🔍 büyüt
            b.showDelete = true; // ❌ silme butonu aç
          });
        },
        onLongPressEnd: (_) {
          setState(() {
            b.scale = 1.0; // normale dön
          });
        },
        onPanStart: (_) {
          widget.onInteract?.call(true);
        },
        onPanUpdate: (details) {
          setState(() {
            b.position += details.delta;
          });
          if (widget.isOverTrash(details.globalPosition)) {
            widget.onDraggingOverTrash?.call(true);
          } else {
            widget.onDraggingOverTrash?.call(false);
          }
        },
        onPanEnd: (_) async {
          widget.onInteract?.call(false);

          if (widget.isOverTrash(
            b.position + Offset(b.width / 2, b.height / 2),
          )) {
            await widget.onDelete();
          } else {
            await widget.onSave();
          }
          widget.onDraggingOverTrash?.call(false);
        },
        child: Transform.scale(
          scale: b.scale, // 📏 büyütme
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.rotate(
                angle: b.rotation,
                child: Opacity(
                  opacity: b.opacity,
                  child: Text(
                    b.text ?? "😀",
                    style: TextStyle(fontSize: b.fixedFontSize),
                  ),
                ),
              ),

              // ❌ Silme butonu
              if (b.showDelete)
                Positioned(
                  top: -10,
                  right: -10,
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.red,
                      child: Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
