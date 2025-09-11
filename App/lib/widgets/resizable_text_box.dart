import 'dart:async';
import 'package:flutter/material.dart';
import '../models/box_item.dart';

class ResizableTextBox extends StatefulWidget {
  final BoxItem box;
  final bool isEditing;
  final VoidCallback onUpdate;   // sadece UI refresh
  final VoidCallback onSave;     // Firestore save
  final void Function(bool edit) onSelect;
  final VoidCallback onDelete;
  final bool Function(Offset) isOverTrash;
  final void Function(bool)? onDraggingOverTrash;
  final void Function(bool active)? onInteract; // stream çakışmasını engellemek için

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
    this.onInteract,
  });

  @override
  State<ResizableTextBox> createState() => _ResizableTextBoxState();
}

class _ResizableTextBoxState extends State<ResizableTextBox> {
  int _overTrashFrames = 0;
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  // gesture state
  Offset? _lastGlobalPoint;
  late double _startW;
  late double _startH;
  late double _startRot;

  // font-fit cache
  String? _fitKey;
  double? _fitSize;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.box.text);

    // Fokus değişince etkileşim bildir + kaydet
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
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ==== font fit ====
  double _fitFontSize(BoxItem b) {
    final key = [
      b.text,
      b.width.toStringAsFixed(2),
      b.height.toStringAsFixed(2),
      b.fontFamily,
      b.bold,
      b.italic,
      b.underline,
      b.align,
    ].join('|');

    if (_fitKey == key && _fitSize != null) return _fitSize!;

    double lo = 1.0, hi = 2000.0;
    final text = b.text.isEmpty ? 'Metin...' : b.text;

    bool fits(double fs) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fs,
            fontFamily: b.fontFamily,
            fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
            decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
            color: b.text.isEmpty ? Colors.grey : Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: b.align,
        maxLines: 1,
      );
      tp.layout(maxWidth: b.width);
      return tp.size.width <= b.width + 0.5 && tp.size.height <= b.height + 0.5;
    }

    for (int i = 0; i < 25; i++) {
      final mid = (lo + hi) / 2;
      if (fits(mid)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    _fitKey = key;
    _fitSize = lo;
    return lo;
  }

  // ==== gestures ====
  void _onScaleStart(ScaleStartDetails d) {
    widget.onInteract?.call(true);
    widget.onSelect(false);

    _startW = widget.box.width;
    _startH = widget.box.height;
    _startRot = widget.box.rotation;
    _lastGlobalPoint = d.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final b = widget.box;
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final floatingEdit = widget.isEditing && kb > 0 && b.type == "textbox";

    // Floating edit modunda sürüklemeyi/rotasyonu kilitle
    if (!floatingEdit) {
      if (d.pointerCount == 1) {
        if (d.focalPointDelta.distanceSquared >= 0.25) {
          b.position += d.focalPointDelta;
        }
      }
      if (d.pointerCount >= 2) {
        if (d.scale > 0) {
          b.width = (_startW * d.scale).clamp(24.0, 4096.0);
          b.height = (_startH * d.scale).clamp(24.0, 4096.0);
          _fitKey = null;
        }
        b.rotation = _startRot + d.rotation;
      }
    }

    _lastGlobalPoint = d.focalPoint;

    final over = widget.isOverTrash(_lastGlobalPoint!);
    if (over) {
      _overTrashFrames++;
    } else {
      _overTrashFrames = 0;
    }
    widget.onDraggingOverTrash?.call(over);

    widget.onUpdate();
  }

  void _onScaleEnd(ScaleEndDetails d) {
    bool shouldDelete = false;

    final over = _lastGlobalPoint != null && widget.isOverTrash(_lastGlobalPoint!);
    if (_overTrashFrames >= 2 && over) {
      shouldDelete = true;
    }

    widget.onDraggingOverTrash?.call(false);
    widget.onInteract?.call(false);

    if (shouldDelete) {
      widget.onDelete();
      return;
    }

    widget.onSave();
  }

  // ==== ölçüm (tek satır) ====
  Size _measureSingleLine(BoxItem b) {
    final tp = TextPainter(
      text: TextSpan(
        text: b.text.isEmpty ? 'Metin...' : b.text,
        style: TextStyle(
          fontSize: (b.autoFontSize ? _fitFontSize(b) : b.fixedFontSize).clamp(6, 2000),
          fontFamily: b.fontFamily,
          fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
          decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    return Size(tp.width + 24, tp.height + 12);
  }

  // ==== paneller ====
  Future<void> _openImageEditPanel() async {
    widget.onInteract?.call(true);
    await showModalBottomSheet(
      context: context,
      builder: (_) {
        final b = widget.box;
        double localRadius = b.borderRadius;
        double localOpacity = b.imageOpacity;

        return StatefulBuilder(builder: (_, setSt) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Resim Ayarları",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // Radius (anlık uygula)
                  Row(
                    children: [
                      const Text("Radius"),
                      Expanded(
                        child: Slider(
                          value: localRadius,
                          min: 0,
                          max: 64,
                          onChanged: (v) {
                            setSt(() => localRadius = v);
                            b.borderRadius = v;
                            widget.onUpdate();
                            widget.onSave(); // anlık kaydet
                          },
                        ),
                      ),
                    ],
                  ),

                  // Opacity (anlık uygula)
                  Row(
                    children: [
                      const Text("Opacity"),
                      Expanded(
                        child: Slider(
                          value: localOpacity,
                          min: 0,
                          max: 1,
                          onChanged: (v) {
                            setSt(() => localOpacity = v);
                            b.imageOpacity = v;
                            widget.onUpdate();
                            widget.onSave();
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Z-index
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.vertical_align_top),
                        label: const Text("En üste"),
                        onPressed: () {
                          b.z = DateTime.now().millisecondsSinceEpoch;
                          widget.onUpdate();
                          widget.onSave();
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.vertical_align_bottom),
                        label: const Text("En alta"),
                        onPressed: () {
                          b.z = -DateTime.now().millisecondsSinceEpoch;
                          widget.onUpdate();
                          widget.onSave();
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      child: const Text("Kapat"),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    ).whenComplete(() => widget.onInteract?.call(false));
  }

  Future<void> _openTextBoxEditPanel() async {
    widget.onInteract?.call(true);
    await showModalBottomSheet(
      context: context,
      builder: (_) {
        final b = widget.box;
        double localRadius = b.borderRadius;
        double localBgOpacity = b.backgroundOpacity;
        int localBgColor = b.backgroundColor;

        Color cFrom(int v) => Color(v);
        final swatches = <int>[
          0xFFFFFFFF,
          0xFFF8F9FA,
          0xFFFFF3CD,
          0xFFE3F2FD,
          0xFFE8F5E9,
          0xFFFFEBEE,
          0xFF212121,
        ];

        return StatefulBuilder(builder: (_, setSt) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Metin Kutusu Ayarları",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // BG color (anında uygula)
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: swatches.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final color = swatches[i];
                        return GestureDetector(
                          onTap: () {
                            setSt(() => localBgColor = color);
                            b.backgroundColor = color;
                            widget.onUpdate();
                            widget.onSave();
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: cFrom(color),
                              border: Border.all(
                                color: color == localBgColor
                                    ? Colors.teal
                                    : Colors.black12,
                                width: color == localBgColor ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // BG opacity (anında uygula)
                  Row(
                    children: [
                      const Text("BG Opacity"),
                      Expanded(
                        child: Slider(
                          value: localBgOpacity,
                          min: 0,
                          max: 1,
                          onChanged: (v) {
                            setSt(() => localBgOpacity = v);
                            b.backgroundOpacity = v;
                            widget.onUpdate();
                            widget.onSave();
                          },
                        ),
                      ),
                    ],
                  ),

                  // radius (anında uygula)
                  Row(
                    children: [
                      const Text("Radius"),
                      Expanded(
                        child: Slider(
                          value: localRadius,
                          min: 0,
                          max: 64,
                          onChanged: (v) {
                            setSt(() => localRadius = v);
                            b.borderRadius = v;
                            widget.onUpdate();
                            widget.onSave();
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Z-index
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.vertical_align_top),
                        label: const Text("En üste"),
                        onPressed: () {
                          b.z = DateTime.now().millisecondsSinceEpoch;
                          widget.onUpdate();
                          widget.onSave();
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.vertical_align_bottom),
                        label: const Text("En alta"),
                        onPressed: () {
                          b.z = -DateTime.now().millisecondsSinceEpoch;
                          widget.onUpdate();
                          widget.onSave();
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      child: const Text("Kapat"),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    ).whenComplete(() => widget.onInteract?.call(false));
  }

  // ==== içerik ====
  Widget _buildContent(BoxItem b) {
    if (b.type == "image") {
      if (b.imageBytes == null || b.imageBytes!.isEmpty) {
        return const Text("Resim yükleniyor...", style: TextStyle(color: Colors.grey));
      }
      return Opacity(
        opacity: b.imageOpacity.clamp(0, 1),
        child: SizedBox.expand(
          child: Image.memory(
            b.imageBytes!,
            fit: BoxFit.cover, // cover + kırp
            gaplessPlayback: true,
          ),
        ),
      );
    }

    // text
    final fitted = b.autoFontSize ? _fitFontSize(b) : b.fixedFontSize;

    return Align(
      alignment: Alignment(
        b.align == TextAlign.left
            ? -1
            : b.align == TextAlign.right
                ? 1
                : 0,
        b.vAlign == 'top'
            ? -1
            : b.vAlign == 'bottom'
                ? 1
                : 0,
      ),
      child: widget.isEditing
          ? TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              maxLines: 1,
              textAlign: b.align,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "Metin...",
              ),
              style: TextStyle(
                fontSize:
                    (b.autoFontSize ? _fitFontSize(b) : b.fixedFontSize).clamp(6, 2000),
                fontFamily: b.fontFamily,
                fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
                fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
                decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
                color: Color(b.textColor),
              ),
              onChanged: (val) {
                b.text = val;

                // tek satır ölç, belli sınıra kadar kutuyu büyüt
                final s = _measureSingleLine(b);
                final media = MediaQuery.of(context);
                final kb = media.viewInsets.bottom;
                final screen = media.size;
                final maxWWhileEditing = screen.width - 32;
                final maxHWhileEditing = (screen.height - kb) * 0.35;

                if (kb > 0) {
                  b.width = s.width.clamp(24.0, maxWWhileEditing);
                  b.height = s.height.clamp(24.0, maxHWhileEditing);
                } else {
                  if (s.width > b.width) b.width = s.width;
                  if (s.height > b.height) b.height = s.height;
                }

                _fitKey = null;
                widget.onUpdate();
              },
              onSubmitted: (_) => widget.onSave(),
            )
          : Text(
              b.text.isEmpty ? "Metin..." : b.text,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              style: TextStyle(
                fontSize: fitted,
                fontFamily: b.fontFamily,
                fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
                fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
                decoration:
                    b.underline ? TextDecoration.underline : TextDecoration.none,
                color: Color(b.textColor),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.box;

    final media = MediaQuery.of(context);
    final kb = media.viewInsets.bottom;
    final screen = media.size;
    const toolbarH = 48.0;

    final floatingEdit = widget.isEditing && kb > 0 && b.type == "textbox";

    // Floating konum: klavyenin bittiği yerin hemen üstü
    final floatLeft = 16.0;
    final availableH = screen.height - kb;
    final floatTop =
        (availableH - b.height - toolbarH - 8).clamp(8.0, availableH - b.height - 8.0);

    final posLeft = floatingEdit ? floatLeft : b.position.dx;
    final posTop = floatingEdit ? floatTop : b.position.dy;
    final angle = floatingEdit ? 0.0 : b.rotation;

    return Positioned(
      left: posLeft,
      top: posTop,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        onDoubleTap: () {
          // paneli aç + stream’e etkileşimde olduğumuzu söyle
          if (widget.box.type == "image") {
            _openImageEditPanel();
          } else {
            _openTextBoxEditPanel();
          }
        },
        onTap: () {
          if (b.type == "textbox") {
            widget.onSelect(true);
            Future.delayed(Duration.zero, () {
              if (!_focusNode.hasFocus) _focusNode.requestFocus();
            });
          } else {
            widget.onSelect(false);
          }
        },
        child: Transform.rotate(
          angle: angle,
          child: SizedBox(
            width: b.width,
            height: b.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // inline toolbar (sadece edit ve textbox iken)
                if (floatingEdit && b.type == "textbox")
                  Positioned(
                    left: 0,
                    top: -toolbarH,
                    child: _buildTextInlineToolbar(b),
                  ),

                ClipRRect(
                  borderRadius: BorderRadius.circular(b.borderRadius),
                  child: Container(
                    width: b.width,
                    height: b.height,
                    color: Color(b.backgroundColor)
                        .withAlpha((b.backgroundOpacity * 255).clamp(0, 255).round()),
                    alignment: Alignment.center,
                    child: _buildContent(b),
                  ),
                ),

                // köşe/kenar handle’ları (seçiliyken)
                // Not: Handle’ları eski sürümde bıraktık; burada görsel sadeleştirme istedinizse kapatabilirsiniz.
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Basit inline text toolbar
  Widget _buildTextInlineToolbar(BoxItem b) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // text color (küçük palet)
            GestureDetector(
              onTap: () {
                final colors = [0xFF000000, 0xFF2962FF, 0xFFD81B60, 0xFF2E7D32, 0xFFF9A825, 0xFFFFFFFF];
                showModalBottomSheet(
                  context: context,
                  builder: (_) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: colors
                            .map((c) => GestureDetector(
                                  onTap: () {
                                    b.textColor = c;
                                    widget.onUpdate();
                                    widget.onSave();
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Color(c),
                                      border: Border.all(color: Colors.black12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                );
              },
              child: const Icon(Icons.color_lens, size: 20),
            ),
            IconButton(
              icon: Icon(Icons.format_bold, size: 20, color: b.bold ? Colors.teal : null),
              onPressed: () {
                b.bold = !b.bold;
                widget.onUpdate();
                widget.onSave();
              },
            ),
            IconButton(
              icon: Icon(Icons.format_italic, size: 20, color: b.italic ? Colors.teal : null),
              onPressed: () {
                b.italic = !b.italic;
                widget.onUpdate();
                widget.onSave();
              },
            ),
            IconButton(
              icon: Icon(Icons.format_underline, size: 20, color: b.underline ? Colors.teal : null),
              onPressed: () {
                b.underline = !b.underline;
                widget.onUpdate();
                widget.onSave();
              },
            ),
            const VerticalDivider(),
            IconButton(
              icon: const Icon(Icons.format_align_left, size: 20),
              onPressed: () {
                b.align = TextAlign.left;
                widget.onUpdate();
                widget.onSave();
              },
            ),
            IconButton(
              icon: const Icon(Icons.format_align_center, size: 20),
              onPressed: () {
                b.align = TextAlign.center;
                widget.onUpdate();
                widget.onSave();
              },
            ),
            IconButton(
              icon: const Icon(Icons.format_align_right, size: 20),
              onPressed: () {
                b.align = TextAlign.right;
                widget.onUpdate();
                widget.onSave();
              },
            ),
            const VerticalDivider(),
            IconButton(
              icon: const Icon(Icons.vertical_align_top, size: 20),
              onPressed: () {
                b.vAlign = 'top';
                widget.onUpdate();
                widget.onSave();
              },
            ),
            IconButton(
              icon: const Icon(Icons.vertical_align_center, size: 20),
              onPressed: () {
                b.vAlign = 'middle';
                widget.onUpdate();
                widget.onSave();
              },
            ),
            IconButton(
              icon: const Icon(Icons.vertical_align_bottom, size: 20),
              onPressed: () {
                b.vAlign = 'bottom';
                widget.onUpdate();
                widget.onSave();
              },
            ),
            const VerticalDivider(),
            TextButton(
              onPressed: () {
                b.autoFontSize = !b.autoFontSize;
                widget.onUpdate();
                widget.onSave();
              },
              child: Text(b.autoFontSize ? "Auto" : "Fixed"),
            ),
            if (!b.autoFontSize)
              SizedBox(
                width: 140,
                child: Slider(
                  value: b.fixedFontSize,
                  min: 6,
                  max: 200,
                  onChanged: (v) {
                    b.fixedFontSize = v;
                    widget.onUpdate();
                    widget.onSave();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
