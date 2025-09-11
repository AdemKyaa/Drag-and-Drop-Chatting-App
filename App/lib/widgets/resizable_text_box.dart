import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/box_item.dart';

class ResizableTextBox extends StatefulWidget {
  final BoxItem box;
  final bool isEditing;
  final VoidCallback onUpdate;
  final VoidCallback onSave;
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
  Timer? _debounce;

  double _startW = 0;
  double _startH = 0;
  Offset _startPos = Offset.zero;
  double _startRot = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.box.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  double _calcFontSize(BoxItem box) {
    final base = box.width < box.height ? box.width : box.height;
    return (base * 0.2).clamp(12, 64);
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.box;

    return Positioned(
      left: box.position.dx,
      top: box.position.dy,
      child: GestureDetector(
        onTap: () => widget.onSelect(false),
        onDoubleTap: () => widget.onSelect(true), // çift tıklama → edit
        onScaleStart: (details) {
          widget.onSelect(false); // sürüklerken seç
          _startW = box.width;
          _startH = box.height;
          _startPos = box.position;
          _startRot = box.rotation;
        },
        onScaleUpdate: (details) {
          setState(() {
            if (details.pointerCount >= 2) {
              final newW = (_startW * details.scale).clamp(40, 600);
              final newH = (_startH * details.scale).clamp(40, 600);
              final dx = (_startW - newW) / 2;
              final dy = (_startH - newH) / 2;
              box.width = newW.toDouble();
              box.height = newH.toDouble();
              box.position = _startPos + Offset(dx, dy);
              box.rotation = _startRot + details.rotation;
            } else {
              box.position += details.focalPointDelta;
            }
          });
          widget.onUpdate();
        },
        onScaleEnd: (_) => widget.onSave(),
        child: Transform.rotate(
          angle: box.rotation,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: box.width,
                height: box.height,
                decoration: BoxDecoration(
                  color: box.type == "textbox"
                      ? Colors.grey.shade200
                      : Colors.transparent,
                  border: box.isSelected
                      ? Border.all(color: Colors.teal, width: 2)
                      : null,
                ),
                alignment: Alignment.center,
                child: box.type == "image" && box.imagePath != null
                    ? Image.network(
                        box.imagePath!,
                        fit: BoxFit.cover,
                        width: box.width,
                        height: box.height,
                      )
                    : (widget.isEditing
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
                              fontSize: _calcFontSize(box),
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
                            onChanged: (val) {
                              box.text = val;
                              widget.onUpdate();
                              _debounce?.cancel();
                              _debounce = Timer(
                                const Duration(milliseconds: 500),
                                () => widget.onSave(),
                              );
                            },
                          )
                        : Text(
                            box.text.isEmpty ? "Metin..." : box.text,
                            textAlign: box.align,
                            style: TextStyle(
                              fontSize: _calcFontSize(box),
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
                              color: box.text.isEmpty
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                          )),
              ),
              if (box.isSelected) ..._buildResizeHandles(box),
            ],
          ),
        ),
      ),
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
          onPanUpdate: (details) =>
              onResize(details.delta.dx, details.delta.dy),
          onPanEnd: (_) => widget.onSave(),
          child: Container(
            width: handleSize,
            height: handleSize,
            color: color,
          ),
        ),
      ));
    }

    // köşeler kırmızı
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

    addHandle(box.width - handleSize / 2, box.height - handleSize / 2,
        Colors.red, (dx, dy) {
      setState(() {
        box.width = (box.width + dx).clamp(40, 600);
        box.height = (box.height + dy).clamp(40, 600);
      });
      widget.onUpdate();
    });

    // kenarlar mavi
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
