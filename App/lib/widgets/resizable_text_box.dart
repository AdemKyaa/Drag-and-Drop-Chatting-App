import 'package:flutter/material.dart';
import '../models/box_item.dart';

class ResizableTextBox extends StatefulWidget {
  final BoxItem box;
  final bool isEditing;
  final VoidCallback onUpdate;
  final void Function(bool edit) onSelect;
  final VoidCallback onDelete;
  final bool Function(Offset) isOverTrash;
  final void Function(bool)? onDraggingOverTrash;

  const ResizableTextBox({
    super.key,
    required this.box,
    required this.isEditing,
    required this.onUpdate,
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

    return Stack(
      children: [
        // Kutunun kendisi
        Positioned(
          left: box.position.dx,
          top: box.position.dy,
          child: GestureDetector(
            onTap: () => widget.onSelect(false),
            onPanStart: (_) => widget.onSelect(false), // sürükleyince seç
            onPanUpdate: (details) {
              setState(() {
                box.position += details.delta;
              });
              widget.onUpdate();

              if (widget.isOverTrash(details.globalPosition)) {
                widget.onDraggingOverTrash?.call(true);
              } else {
                widget.onDraggingOverTrash?.call(false);
              }
            },
            onPanEnd: (_) {
              final renderBox = context.findRenderObject() as RenderBox;
              final center = renderBox
                  .localToGlobal(Offset(box.width / 2, box.height / 2));
              if (widget.isOverTrash(center)) {
                widget.onDelete();
              }
              widget.onDraggingOverTrash?.call(false);
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
                            fontWeight: box.bold
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontStyle: box.italic
                                ? FontStyle.italic
                                : FontStyle.normal,
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
                                  TextPosition(
                                      offset: _controller.text.length),
                                );
                              }
                            } else {
                              box.text = value;
                            }
                            widget.onUpdate();
                          },
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
        ),

        // ✅ Metin düzenleme paneli
        if (widget.isEditing)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Card(
                elevation: 4,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.format_bold,
                          color: box.bold ? Colors.teal : Colors.black),
                      onPressed: () {
                        setState(() => box.bold = !box.bold);
                        widget.onUpdate();
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.format_italic,
                          color: box.italic ? Colors.teal : Colors.black),
                      onPressed: () {
                        setState(() => box.italic = !box.italic);
                        widget.onUpdate();
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.format_underline,
                          color: box.underline ? Colors.teal : Colors.black),
                      onPressed: () {
                        setState(() => box.underline = !box.underline);
                        widget.onUpdate();
                      },
                    ),
                    const VerticalDivider(),
                    IconButton(
                      icon: const Icon(Icons.format_align_left),
                      onPressed: () {
                        setState(() => box.align = TextAlign.left);
                        widget.onUpdate();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_align_center),
                      onPressed: () {
                        setState(() => box.align = TextAlign.center);
                        widget.onUpdate();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_align_right),
                      onPressed: () {
                        setState(() => box.align = TextAlign.right);
                        widget.onUpdate();
                      },
                    ),
                    const VerticalDivider(),
                    IconButton(
                      icon: Icon(Icons.format_list_bulleted,
                          color: box.bullet ? Colors.teal : Colors.black),
                      onPressed: () {
                        setState(() => box.bullet = !box.bullet);
                        widget.onUpdate();
                      },
                    ),
                    const VerticalDivider(),
                    DropdownButton<String>(
                      value: box.fontFamily,
                      items: const [
                        DropdownMenuItem(
                            value: "Roboto", child: Text("Roboto")),
                        DropdownMenuItem(
                            value: "Arial", child: Text("Arial")),
                        DropdownMenuItem(
                            value: "Times New Roman",
                            child: Text("Times")),
                        DropdownMenuItem(
                            value: "Courier New", child: Text("Courier")),
                      ],
                      onChanged: (val) {
                        setState(() => box.fontFamily = val ?? "Roboto");
                        widget.onUpdate();
                      },
                    ),
                    Slider(
                      value: box.fontSize,
                      min: 10,
                      max: 40,
                      onChanged: (val) {
                        setState(() => box.fontSize = val);
                        widget.onUpdate();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildResizeHandles(BoxItem box) {
    const double handleSize = 16;
    final List<Widget> handles = [];

    void addHandle(double left, double top, Color color,
        void Function(double dx, double dy) onResize) {
      handles.add(Positioned(
        left: left,
        top: top,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) => onResize(details.delta.dx, details.delta.dy),
          child: Container(
            width: handleSize,
            height: handleSize,
            color: color,
          ),
        ),
      ));
    }

    // köşeler (kırmızı)
    addHandle(-handleSize / 2, -handleSize / 2, Colors.red, (dx, dy) {
      setState(() {
        box.width = (box.width - dx).clamp(40, 600);
        box.height = (box.height - dy).clamp(40, 600);
        box.position += Offset(dx, dy);
      });
      widget.onUpdate();
    });
    addHandle(box.width - handleSize / 2, -handleSize / 2, Colors.red, (dx, dy) {
      setState(() {
        box.width = (box.width + dx).clamp(40, 600);
        box.height = (box.height - dy).clamp(40, 600);
        box.position += Offset(0, dy);
      });
      widget.onUpdate();
    });
    addHandle(-handleSize / 2, box.height - handleSize / 2, Colors.red,
        (dx, dy) {
      setState(() {
        box.width = (box.width - dx).clamp(40, 600);
        box.height = (box.height + dy).clamp(40, 600);
        box.position += Offset(dx, 0);
      });
      widget.onUpdate();
    });
    addHandle(
        box.width - handleSize / 2, box.height - handleSize / 2, Colors.red,
        (dx, dy) {
      setState(() {
        box.width = (box.width + dx).clamp(40, 600);
        box.height = (box.height + dy).clamp(40, 600);
      });
      widget.onUpdate();
    });

    // kenarlar (mavi)
    addHandle(box.width / 2 - handleSize / 2, -handleSize / 2, Colors.blue,
        (dx, dy) {
      setState(() {
        box.height = (box.height - dy).clamp(40, 600);
        box.position += Offset(0, dy);
      });
      widget.onUpdate();
    });
    addHandle(box.width / 2 - handleSize / 2, box.height - handleSize / 2,
        Colors.blue, (dx, dy) {
      setState(() {
        box.height = (box.height + dy).clamp(40, 600);
      });
      widget.onUpdate();
    });
    addHandle(-handleSize / 2, box.height / 2 - handleSize / 2, Colors.blue,
        (dx, dy) {
      setState(() {
        box.width = (box.width - dx).clamp(40, 600);
        box.position += Offset(dx, 0);
      });
      widget.onUpdate();
    });
    addHandle(box.width - handleSize / 2, box.height / 2 - handleSize / 2,
        Colors.blue, (dx, dy) {
      setState(() {
        box.width = (box.width + dx).clamp(40, 600);
      });
      widget.onUpdate();
    });

    return handles;
  }
}
