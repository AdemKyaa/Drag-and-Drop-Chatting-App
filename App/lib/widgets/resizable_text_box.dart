import 'package:flutter/material.dart';
import '../models/box_item.dart';

class ResizableTextBox extends StatefulWidget {
  final BoxItem box;
  final bool isEditing;
  final VoidCallback onUpdate;   // UI update
  final VoidCallback onSave;     // Firestore save
  final void Function(bool edit) onSelect;
  final VoidCallback onDelete;
  final bool Function(Offset) isOverTrash;
  final void Function(bool)? onDraggingOverTrash;

  const ResizableTextBox({
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
  State<ResizableTextBox> createState() => _ResizableTextBoxState();
}

class _ResizableTextBoxState extends State<ResizableTextBox> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.box.text);
  }

  @override
  void didUpdateWidget(covariant ResizableTextBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditing && _controller.text != widget.box.text) {
      _controller.text = widget.box.text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.box;

    return Positioned(
      left: box.position.dx,
      top: box.position.dy,
      child: GestureDetector(
        onTap: () => widget.onSelect(false),
        onPanStart: (_) => widget.onSelect(false),
        onPanUpdate: (details) {
          setState(() {
            box.position += details.delta;
          });
          widget.onUpdate();
        },
        onPanEnd: (_) {
          final renderBox = context.findRenderObject() as RenderBox;
          final center =
              renderBox.localToGlobal(Offset(box.width / 2, box.height / 2));
          if (widget.isOverTrash(center)) {
            widget.onDelete();
          }
          widget.onDraggingOverTrash?.call(false);
          widget.onSave(); // ✅ konum bırakıldığında kaydet
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: box.width,
              height: box.height,
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: widget.isEditing
                  ? TextField(
                      controller: _controller,
                      autofocus: true,
                      maxLines: null,
                      textAlign: box.align,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "Metin...",
                      ),
                      style: TextStyle(
                        fontSize: box.fontSize,
                        fontFamily: box.fontFamily,
                        fontWeight:
                            box.bold ? FontWeight.bold : FontWeight.normal,
                        fontStyle:
                            box.italic ? FontStyle.italic : FontStyle.normal,
                        decoration: box.underline
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                      onChanged: (value) {
                        if (box.bullet) {
                          final lines = value.split('\n');
                          for (int i = 0; i < lines.length; i++) {
                            if (lines[i].isNotEmpty &&
                                !lines[i].startsWith("• ")) {
                              lines[i] = "• ${lines[i]}";
                            }
                          }
                          final newText = lines.join('\n');
                          if (newText != box.text) {
                            box.text = newText;
                            _controller.text = newText;
                            _controller.selection =
                                TextSelection.fromPosition(
                              TextPosition(offset: _controller.text.length),
                            );
                          }
                        } else {
                          box.text = value;
                        }
                        widget.onUpdate();
                        widget.onSave(); // ✅ yazı değişince kaydet
                      },
                      onEditingComplete: widget.onSave,
                      onSubmitted: (_) => widget.onSave(),
                    )
                  : GestureDetector(
                      onTap: () => widget.onSelect(true),
                      child: Text(
                        box.text.isEmpty ? "Metin..." : box.text,
                        textAlign: box.align,
                        style: TextStyle(
                          fontSize: box.fontSize,
                          fontFamily: box.fontFamily,
                          fontWeight: box.bold
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontStyle: box.italic
                              ? FontStyle.italic
                              : FontStyle.normal,
                          decoration: box.underline
                              ? TextDecoration.underline
                              : TextDecoration.none,
                          color:
                              box.text.isEmpty ? Colors.grey : Colors.black,
                        ),
                      ),
                    ),
            ),
            if (box.isSelected) ..._buildResizeHandles(box),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildResizeHandles(BoxItem box) {
    const double handleSize = 32;
    final List<Widget> handles = [];

    void addHandle(double left, double top, Color color,
        void Function(double dx, double dy) onResize) {
      handles.add(Positioned(
        left: left,
        top: top,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) =>
              onResize(details.delta.dx, details.delta.dy),
          onPanEnd: (_) => widget.onSave(), // ✅ resize bırakıldığında kaydet
          child: Container(
            width: handleSize,
            height: handleSize,
            color: color,
          ),
        ),
      ));
    }

    // köşe ve kenar handle’lar → kaydetme eklendi
    addHandle(-handleSize / 2 + 16, -handleSize / 2 + 16, Colors.red, (dx, dy) {
      setState(() {
        box.width = (box.width - dx).clamp(40, 600);
        box.height = (box.height - dy).clamp(40, 600);
        box.position += Offset(dx, dy);
      });
      widget.onUpdate();
    });

    addHandle(box.width - handleSize / 2 - 16, -handleSize / 2 + 16, Colors.red, (dx, dy) {
      setState(() {
        box.width = (box.width + dx).clamp(40, 600);
        box.height = (box.height - dy).clamp(40, 600);
        box.position += Offset(0, dy);
      });
      widget.onUpdate();
    });

    addHandle(-handleSize / 2 + 16, box.height - handleSize / 2 - 16, Colors.red,
        (dx, dy) {
      setState(() {
        box.width = (box.width - dx).clamp(40, 600);
        box.height = (box.height + dy).clamp(40, 600);
        box.position += Offset(dx, 0);
      });
      widget.onUpdate();
    });

    addHandle(box.width - handleSize / 2 - 16, box.height - handleSize / 2 - 16,
        Colors.red, (dx, dy) {
      setState(() {
        box.width = (box.width + dx).clamp(40, 600);
        box.height = (box.height + dy).clamp(40, 600);
      });
      widget.onUpdate();
    });

    // kenarlar
    addHandle(box.width / 2 - handleSize / 2, -handleSize / 2 + 16, Colors.blue,
        (dx, dy) {
      setState(() {
        box.height = (box.height - dy).clamp(40, 600);
        box.position += Offset(0, dy);
      });
      widget.onUpdate();
    });

    addHandle(box.width / 2 - handleSize / 2, box.height - handleSize / 2 - 16,
        Colors.blue, (dx, dy) {
      setState(() {
        box.height = (box.height + dy).clamp(40, 600);
      });
      widget.onUpdate();
    });

    addHandle(-handleSize / 2 + 16, box.height / 2 - handleSize / 2, Colors.blue,
        (dx, dy) {
      setState(() {
        box.width = (box.width - dx).clamp(40, 600);
        box.position += Offset(dx, 0);
      });
      widget.onUpdate();
    });

    addHandle(box.width - handleSize / 2 - 16, box.height / 2 - handleSize / 2,
        Colors.blue, (dx, dy) {
      setState(() {
        box.width = (box.width + dx).clamp(40, 600);
      });
      widget.onUpdate();
    });

    return handles;
  }
}
