import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import '../../models/box_item.dart';
import '../panels/text_edit_panel.dart';
import '../object/handles/outlines.dart';

class TextObject extends StatefulWidget {
  final BoxItem box;
  final String displayLang; // gösterilecek dil
  final bool isEditing;
  final VoidCallback onUpdate;
  final VoidCallback onSave;
  final void Function(bool edit) onSelect;
  final VoidCallback onDelete;
  final bool Function(Offset) isOverTrash;
  final void Function(bool)? onDraggingOverTrash;
  final void Function(bool)? onInteract;
  final void Function(BoxItem box, int pointerId, Offset globalPos)? onPrimaryPointerDown;
  final VoidCallback? onBringToFront;
  final VoidCallback? onSendToBack;

  const TextObject({
    super.key,
    required this.box,
    required this.displayLang,
    required this.isEditing,
    required this.onUpdate,
    required this.onSave,
    required this.onSelect,
    required this.onDelete,
    required this.isOverTrash,
    this.onDraggingOverTrash,
    this.onInteract,
    this.onPrimaryPointerDown,
    this.onBringToFront,
    this.onSendToBack,
  });

  @override
  State<TextObject> createState() => _TextObjectState();
}

class _TextObjectState extends State<TextObject> {
  static const double _padH = 16;
  static const double _padV = 12;
  static const double _toolbarH = 48;

  int _overTrashFrames = 0;
  Offset? _lastGlobalPoint;
  late double _startRot;
  late double _startFontSize;

  // === Gesture ===
  void _onScaleStart(ScaleStartDetails d) {
    if (!widget.box.isSelected) widget.onSelect(false);
    widget.onInteract?.call(true);

    _startRot = widget.box.rotation;
    _lastGlobalPoint = d.focalPoint;
    _startFontSize = widget.box.fixedFontSize;
  }

  Size _measureText(BoxItem b, {double maxWidth = 2000}) {
    final baseStyle = GoogleFonts.getFont(
      b.fontFamily.isEmpty ? 'Roboto' : b.fontFamily,
      textStyle: GoogleFonts.getFont(
        b.fontFamily.isEmpty ? 'Roboto' : b.fontFamily,
        textStyle: TextStyle(
          fontSize: b.fixedFontSize,
          fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
          decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
          color: Color(b.textColor),
        ),
      )
    );

    final span = TextSpan(
      style: baseStyle,
      children: b.styledSpans(baseStyle),
    );

    final tp = TextPainter(
      text: span,
      textAlign: b.align,
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    return Size(tp.width, tp.height);
  }

  int _lineCount(BoxItem b, {double maxWidth = 2000}) {
    final style = GoogleFonts.getFont(
      b.fontFamily.isEmpty ? 'Roboto' : b.fontFamily,
      textStyle: TextStyle(fontSize: b.fixedFontSize),
    );

    final span = TextSpan(style: style, children: b.styledSpans(style));

    final tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    return tp.computeLineMetrics().length;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final b = widget.box;
    if (d.pointerCount == 1) {
      if (d.focalPointDelta.distanceSquared >= 0.25) {
        final dx = d.focalPointDelta.dx;
        final dy = d.focalPointDelta.dy;

        // kutunun açısını tersine döndür → delta’yı local eksene çevir
        final angle = -(_startRot + d.rotation);
        final rotatedDx = dx * cos(angle) + dy * sin(angle);
        final rotatedDy = -(dx * sin(angle) - dy * cos(angle));

        b.position += Offset(rotatedDx, rotatedDy);
      }
  }

    if (d.pointerCount >= 2) {
      if (d.scale > 0) {
        // 1) Yeni font size
        final newFont = (_startFontSize * d.scale).clamp(8.0, 300.0);
        b.fixedFontSize = newFont;

        // 2) Yeni metin ölçümü
        final textSize = _measureText(b);
        final lineCount = _lineCount(b);

        const padH = 32.0, padV = 24.0;
        b.width = (textSize.width + padH).clamp(24, 4096.0);
        b.height = (lineCount * newFont * 1.2 + padV).clamp(24.0, 4096.0);
      }

      // Rotation her frame güncel rotation ile hesaplanmalı
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

  // === Content ===
  Widget _buildContent(BoxItem b) {
    _recalcBoxSize(b);
    b.textFor(widget.displayLang);

    final baseStyle = GoogleFonts.getFont(
      b.fontFamily.isEmpty ? "Roboto" : b.fontFamily,
      textStyle: TextStyle(
        fontSize: b.fixedFontSize,
        fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
        fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
        decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
        color: Color(b.textColor),
      ),
    );

    return RichText(
      textAlign: b.align,
      text: TextSpan(
        style: baseStyle,
        children: b.styledSpans(baseStyle),
      ),
    );
  }

  void _recalcBoxSize(BoxItem b) {
    final baseStyle = GoogleFonts.getFont(
      b.fontFamily.isEmpty ? 'Roboto' : b.fontFamily,
      textStyle: TextStyle(
        fontSize: b.fixedFontSize,
        fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
        fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
        decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
        color: Color(b.textColor),
      ),
    );

    final span = TextSpan(
      style: baseStyle,
      children: b.styledSpans(baseStyle),
    );

    final tp = TextPainter(
      text: span,
      textAlign: b.align,
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: 2000);

    final lineCount = tp.computeLineMetrics().length;
    const padH = 32.0, padV = 24.0;
    
    final newW = (tp.width + padH).clamp(24.0, 4096.0);
    final newH = (lineCount * b.fixedFontSize * 1.2 + padV)
    .clamp(24.0, 4096.0);

    if ((b.width - newW).abs() > 0.5 || (b.height - newH).abs() > 0.5) {
      b.width = newW;
      b.height = newH;
    }
  }

  Future<void> _openEditPanel() async {
    await showModalBottomSheet(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => TextEditPanel(
        box: widget.box,
        onUpdate: widget.onUpdate,
        onSave: widget.onSave,
        onBringToFront: widget.onBringToFront,
        onSendToBack: widget.onSendToBack,
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
        child: Transform.rotate(
          angle: b.rotation,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) {
              widget.onPrimaryPointerDown?.call(widget.box, e.pointer, e.position);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
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
                }
              },
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
                            borderRadius: BorderRadius.circular(
                              b.borderRadius * (b.width < b.height ? b.width : b.height),
                            ),
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
                              painter: OutlinePainter(
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
      ),
    );
  }
}