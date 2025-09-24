// lib/widgets/object/image_object.dart
import 'dart:math';
import 'package:flutter/material.dart';

import '../../models/box_item.dart';
import '../panels/image_edit_panel.dart';
import '../object/handles/outlines.dart';
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

  // z-index
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
  Offset? _lastGlobalPoint;
  late double _startW;
  late double _startH;
  late double _startRot;

  int _overTrashFrames = 0;

  // === Gesture ===
  void _onScaleStart(ScaleStartDetails d) {
    if (!widget.box.isSelected) widget.onSelect(false);
    widget.onInteract?.call(true);

    _startW = widget.box.width;
    _startH = widget.box.height;
    _startRot = widget.box.rotation;
    _lastGlobalPoint = d.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final b = widget.box;

    if (d.pointerCount == 1) {
      if (d.focalPointDelta.distanceSquared >= 0.25) {
        final dx = d.focalPointDelta.dx;
        final dy = d.focalPointDelta.dy;

        final angle = -(_startRot + d.rotation);
        final rotatedDx = dx * cos(angle) + dy * sin(angle);
        final rotatedDy = -(dx * sin(angle) - dy * cos(angle));

        b.position += Offset(rotatedDx, rotatedDy);
      }
    }

    if (d.pointerCount >= 2) {
      if (d.scale > 0) {
        b.width = (_startW * d.scale).clamp(32.0, 4096.0);
        b.height = (_startH * d.scale).clamp(32.0, 4096.0);
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
                        opacity: b.imageOpacity.clamp(0.0, 1.0),
                        child: SizedBox(
                          width: b.width,
                          height: b.height,
                          child: (b.imageBytes != null)
                              ? Image.memory(b.imageBytes!, fit: BoxFit.cover)
                              : (b.imageUrl != null && b.imageUrl!.isNotEmpty)
                                  ? Image.network(b.imageUrl!, fit: BoxFit.cover)
                                  : const SizedBox.shrink(),
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