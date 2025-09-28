import 'package:flutter/material.dart';
import '../../models/box_item.dart';
import '../panels/emoji_edit_panel.dart';

class ResizableEmojiBox extends StatefulWidget {
  final BoxItem box;
  final bool isEditing;
  final VoidCallback onUpdate;
  final Future<void> Function() onSave;
  final void Function(bool edit) onSelect;
  final Future<void> Function() onDelete;
  final bool Function(Offset) isOverTrash;
  final void Function(bool active)? onInteract;
  final void Function(bool)? onDraggingOverTrash;
  final void Function(BoxItem box, int pointerId, Offset globalPos)? onPrimaryPointerDown;
  final VoidCallback? onBringToFront;
  final VoidCallback? onSendToBack;
  final String currentUserId; // ✅ dil ayarı ve user işlemleri için eklendi

  const ResizableEmojiBox({
    super.key,
    required this.box,
    required this.isEditing,
    required this.onUpdate,
    required this.onSave,
    required this.onSelect,
    required this.onDelete,
    required this.isOverTrash,
    required this.onInteract,
    this.onDraggingOverTrash,
    this.onPrimaryPointerDown,
    this.onBringToFront,
    this.onSendToBack,
    required this.currentUserId,
  });

  @override
  State<ResizableEmojiBox> createState() => _ResizableEmojiBoxState();
}

class _ResizableEmojiBoxState extends State<ResizableEmojiBox> {
  Offset? _dragStart;
  Offset? _lastGlobalPos;

  Future<void> _openEditPanel() async {
    final b = widget.box;
    await showModalBottomSheet(
      context: context,
      builder: (_) => EmojiEditPanel(
        box: b,
        onUpdate: widget.onUpdate,
        onSave: widget.onSave,
        onClose: () => widget.onSelect(false),
        onBringToFront: widget.onBringToFront,
        onSendToBack: widget.onSendToBack,
        currentUserId: widget.currentUserId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.box;

    return Positioned(
      left: b.position.dx,
      top: b.position.dy,
      child: Listener(
        onPointerDown: (e) {
          widget.onPrimaryPointerDown?.call(widget.box, e.pointer, e.position);
        },
        child: GestureDetector(
          onTap: () => widget.onSelect(false),

          onDoubleTap: () async {
            b.isSelected = true;
            widget.onUpdate();
            widget.onSelect(false);
            await _openEditPanel();
          },

          onPanStart: (details) {
            _dragStart = details.globalPosition;
            _lastGlobalPos = details.globalPosition;
            widget.onSelect(false);
            widget.onInteract?.call(true);
          },

          onPanUpdate: (details) {
            final start = _dragStart;
            if (start == null) return;

            final delta = details.globalPosition - start;
            _dragStart = details.globalPosition;
            _lastGlobalPos = details.globalPosition;

            setState(() {
              b.position += delta;
            });

            final overTrash = widget.isOverTrash(details.globalPosition);
            widget.onDraggingOverTrash?.call(overTrash);
          },

          onPanEnd: (details) async {
            widget.onInteract?.call(false);

            final releasePos = _lastGlobalPos;
            if (releasePos != null && widget.isOverTrash(releasePos)) {
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
                style: TextStyle(fontSize: b.fixedFontSize),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
