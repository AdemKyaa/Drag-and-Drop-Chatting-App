import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/box_item.dart';
import '../panels/text_edit_panel.dart';

class TextObject extends StatefulWidget {
  final BoxItem box;
  final bool isEditing;
  final VoidCallback onUpdate;
  final VoidCallback onSave;
  final void Function(bool edit) onSelect;
  final VoidCallback onDelete;
  final bool Function(Offset) isOverTrash;
  final void Function(bool)? onDraggingOverTrash;
  final void Function(bool active)? onInteract;

  const TextObject({
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
  State<TextObject> createState() => _TextObjectState();
}

class _TextObjectState extends State<TextObject> {
  static const double _padH = 12;
  static const double _padV = 8;
  static const double _toolbarH = 48;

  int _overTrashFrames = 0;
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  Offset? _lastGlobalPoint;
  late double _startW;
  late double _startH;
  late double _startRot;
  late double _startFontSize;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.box.text);

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        widget.onInteract?.call(true);
      } else {
        widget.onSave();
        widget.onInteract?.call(false);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ==== gesture ====
  void _onScaleStart(ScaleStartDetails d) {
    if (!widget.box.isSelected) {
      widget.onSelect(false);
    }
    widget.onInteract?.call(true);

    _startW = widget.box.width;
    _startH = widget.box.height;
    _startRot = widget.box.rotation;
    _lastGlobalPoint = d.focalPoint;
    _startFontSize = widget.box.fixedFontSize;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final b = widget.box;

    if (d.pointerCount == 1) {
      if (d.focalPointDelta.distanceSquared >= 0.25) {
        b.position += d.focalPointDelta;
      }
    }
    if (d.pointerCount >= 2) {
      if (d.scale > 0) {
        b.width = (_startW * d.scale).clamp(24.0, 4096.0);
        b.height = (_startH * d.scale).clamp(24.0, 4096.0);
        b.fixedFontSize = (_startFontSize * d.scale).clamp(8.0, 300.0);
      }
      b.rotation = _startRot + d.rotation;
    }

    _lastGlobalPoint = d.focalPoint;
    bool over = _lastGlobalPoint != null && widget.isOverTrash(_lastGlobalPoint!);
    _overTrashFrames = over ? (_overTrashFrames + 1) : 0;
    widget.onDraggingOverTrash?.call(over);

    widget.onUpdate();
  }

  void _onScaleEnd(ScaleEndDetails d) {
    bool shouldDelete = false;
    final over = _lastGlobalPoint != null && widget.isOverTrash(_lastGlobalPoint!);
    if (_overTrashFrames >= 2 && over) shouldDelete = true;

    widget.onDraggingOverTrash?.call(false);
    widget.onInteract?.call(false);
    widget.onUpdate();

    if (shouldDelete) {
      widget.onDelete();
      return;
    }
    widget.onSave();
  }

  // ==== content ====
  Widget _buildContent(BoxItem b) {
    final editHere = widget.isEditing;

    if (editHere) {
      return TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        maxLines: null,
        minLines: 1,
        expands: false,
        textAlign: b.align,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: "Metin...",
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
        ),
        style: TextStyle(
          fontSize: b.fixedFontSize,
          fontFamily: b.fontFamily,
          fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
          decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
          color: Color(b.textColor),
        ),
        onChanged: (val) {
          b.text = val;
          widget.onUpdate();
        },
        onSubmitted: (_) => widget.onSave(),
      );
    }

    return RichText(
      textAlign: b.align,
      text: TextSpan(
        text: b.text.isEmpty ? "Metin..." : b.text,
        style: TextStyle(
          fontSize: b.fixedFontSize,
          fontFamily: b.fontFamily,
          fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
          decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
          color: b.text.isEmpty ? Colors.grey : Color(b.textColor),
        ),
      ),
    );
  }

  Future<void> _openEditPanel() async {
    await showModalBottomSheet(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => TextEditPanel(
        box: widget.box,
        onUpdate: widget.onUpdate,
        onSave: widget.onSave,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.box;
    final showToolbar = widget.isEditing;

    return Positioned(
      left: b.position.dx,
      top: b.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        onDoubleTap: () async {
          b.isSelected = true;
          widget.onUpdate();
          widget.onSelect(false);
          await _openEditPanel();
        },
        onTap: () {
          final alreadySelected = b.isSelected;
          if (!alreadySelected) {
            b.isSelected = true;
            widget.onSelect(false);
          } else {
            widget.onSelect(true);
            Future.microtask(() {
              if (!_focusNode.hasFocus) _focusNode.requestFocus();
            });
          }
        },
        child: Transform.rotate(
          angle: b.rotation,
          child: SizedBox(
            width: b.width,
            height: b.height + (showToolbar ? (_toolbarH + 6) : 0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: (showToolbar ? (_toolbarH + 6) : 0),
                  child: Container(
                    width: b.width,
                    height: b.height,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: _padH, vertical: _padV),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(b.borderRadius * (b.width < b.height ? b.width : b.height)),
                      color: Color(b.backgroundColor).withAlpha(
                        (b.backgroundOpacity * 255).clamp(0, 255).round(),
                      ),
                    ),
                    child: _buildContent(b),
                  ),
                ),

                if (b.isSelected)
                  Positioned(
                    left: 0,
                    top: (showToolbar ? (_toolbarH + 6) : 0),
                    child: IgnorePointer(
                      child: CustomPaint(
                        size: Size(b.width, b.height),
                        painter: _OutlinePainter(
                          radius: b.borderRadius,
                          show: true,
                          color: Colors.blueAccent,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinePainter extends CustomPainter {
  final double radius;
  final bool show;
  final Color color;
  final double strokeWidth;

  _OutlinePainter({
    required this.radius,
    required this.show,
    required this.color,
    this.strokeWidth = 2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!show) return;
    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(radius),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_OutlinePainter old) =>
      old.radius != radius ||
      old.show != show ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
