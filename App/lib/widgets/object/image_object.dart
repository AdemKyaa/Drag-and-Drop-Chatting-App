import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/box_item.dart';
import '../object/handles/outlines.dart';
import '../panels/image_edit_panel.dart';
import '../object/handles/resize_handles.dart';

  class ImageObject extends StatefulWidget {
    final BoxItem box;
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

    const ImageObject({
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
      this.onPrimaryPointerDown,
      this.onBringToFront,
      this.onSendToBack,
    });

    @override
    State<ImageObject> createState() => _ImageObjectState();
  }

  class _ImageObjectState extends State<ImageObject> {
    static const double _toolbarH = 48;

    int _overTrashFrames = 0;
    Offset? _lastGlobalPoint;
    late double _startW, _startH, _startRot;

    void _onScaleStart(ScaleStartDetails d) {
      if (!widget.box.isSelected) widget.onSelect(false);
      widget.onInteract?.call(true);

      final b = widget.box;
      _startW = b.width;
      _startH = b.height;
      _startRot = b.rotation;
      _lastGlobalPoint = d.focalPoint;
    }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final b = widget.box;

    if (d.pointerCount == 1) {
      // Tek parmak → sürükleme
      if (d.focalPointDelta.distanceSquared >= 0.25) {
        final dx = d.focalPointDelta.dx;
        final dy = d.focalPointDelta.dy;

        // açılı objelerde kaymayı doğru hesapla
        final angle = -(_startRot + d.rotation);
        final rotatedDx = dx * cos(angle) + dy * sin(angle);
        final rotatedDy = -(dx * sin(angle) - dy * cos(angle));

        b.position += Offset(rotatedDx, rotatedDy);
      }
    }

    if (d.pointerCount >= 2) {
      // Çift parmak → ölçek + rotate
      final newW = (_startW * d.scale).clamp(40.0, 4096.0);
      final newH = (_startH * d.scale).clamp(40.0, 4096.0);
      b.width = newW;
      b.height = newH;
      b.rotation = _startRot + d.rotation;
    }

    widget.onUpdate();
  }

  void _onScaleEnd(ScaleEndDetails d) {
    widget.onDraggingOverTrash?.call(false);
    widget.onInteract?.call(false);
    widget.onUpdate();

    final over = _lastGlobalPoint != null && widget.isOverTrash(_lastGlobalPoint!);
    if (over) {
      widget.onDelete();
    } else {
      widget.onSave();
    }
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
            behavior: HitTestBehavior.translucent,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            onDoubleTap: () async {
              b.isSelected = true;
              widget.onUpdate();
              widget.onSelect(false);
              await showModalBottomSheet(
                context: context,
                builder: (_) => ImageEditPanel(
                  box: b,
                  onUpdate: widget.onUpdate,
                  onSave: widget.onSave,
                  onBringToFront: widget.onBringToFront,
                  onSendToBack: widget.onSendToBack,
                ),
              );
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
                  // Görsel
                  Positioned(
                    top: (showToolbar ? (_toolbarH + 6) : 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        b.borderRadius * (b.width < b.height ? b.width : b.height),
                        ),
                        child: Opacity(
                          opacity: b.backgroundOpacity.clamp(0.0, 1.0), // panelden kontrol edeceğiz
                          child:
                          Container(
                          width: b.width,
                          height: b.height,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              b.borderRadius * (b.width < b.height ? b.width : b.height),
                            ),
                            color: Color(b.backgroundColor).withAlpha(
                              (b.backgroundOpacity * 255).clamp(0, 255).round(),
                            ),
                            image: b.imageBytes != null
                                ? DecorationImage(image: MemoryImage(b.imageBytes!), fit: BoxFit.cover)
                                : (b.imageUrl != null && b.imageUrl!.isNotEmpty
                                    ? DecorationImage(image: NetworkImage(b.imageUrl!), fit: BoxFit.cover)
                                    : null),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Outline
                  if (b.isSelected)
                    IgnorePointer(
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

                  // Handle’lar
                  if (b.isSelected)
                    Positioned.fill(
                    child: ResizeHandles(
                      box: b,
                      onUpdate: widget.onUpdate,
                      onSave: widget.onSave,
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
