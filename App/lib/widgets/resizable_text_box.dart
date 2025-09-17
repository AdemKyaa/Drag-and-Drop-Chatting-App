import 'dart:async';
import 'package:flutter/material.dart';
import '../models/box_item.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ResizableTextBox extends StatefulWidget {
  final BoxItem box;
  final bool isEditing;
  final VoidCallback onUpdate;   // sadece UI refresh
  final VoidCallback onSave;     // Firestore save
  final void Function(bool edit) onSelect;
  final VoidCallback onDelete;
  final bool Function(Offset) isOverTrash;
  final void Function(bool)? onDraggingOverTrash;
  final void Function(bool active)? onInteract;
  final void Function(bool hasFocus, BoxItem box)? onTextFocusChange;
  final VoidCallback? onPanelOpen;
  final VoidCallback? onPanelClose;

  // Eklenen props:
  final bool inlineToolbar;   // burada toolbar çizilsin mi
  final bool floatOnEdit;     // editte kutuyu klavyeye taşı
  final bool useExternalEditor; // dış overlay editör kullanılıyor mu
  final VoidCallback? onDeselect;

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
    this.onTextFocusChange,
    this.inlineToolbar = false,
    this.floatOnEdit = false,
    this.useExternalEditor = false,
    this.onDeselect,
    this.onPanelOpen,
    this.onPanelClose,
  });

  @override
  State<ResizableTextBox> createState() => _ResizableTextBoxState();
}

class _ResizableTextBoxState extends State<ResizableTextBox> {
  // padding (text kutuları için)
  static const double _padH = 12;
  static const double _padV = 8;

  // toolbar yüksekliği
  static const double _toolbarH = 48;

  int _overTrashFrames = 0;
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  // gesture state
  Offset? _lastGlobalPoint;
  late double _startW;
  late double _startH;
  late double _startRot;
  late double _startFontSize;

  // font-fit cache (tek satır)

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.box.text);

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        widget.onInteract?.call(true);
        widget.onTextFocusChange?.call(true, widget.box);
      } else {
        widget.onSave();
        widget.onInteract?.call(false);
        widget.onTextFocusChange?.call(false, widget.box);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ResizableTextBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.useExternalEditor &&
        widget.isEditing &&
        _controller.text != widget.box.text) {
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

  // ---- Radius: 0..0.5 => minSide * factor, >1 => px
  double _effectiveRadius(BoxItem b) {
    final minSide = b.width < b.height ? b.width : b.height;
    final r = b.borderRadius;
    final asPx = (r <= 1.0) ? (r * minSide) : r;
    final maxR = minSide / 2;
    return (asPx.clamp(0.0, maxR)).toDouble();
  }

  // ==== tek satır font fit (canvas görünümü için) ====

  double _measureSingleLineWidth(BoxItem b, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: b.text.isEmpty ? ' ' : b.text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(); // sınırsız
    // son harf kırpılmasın diye +1
    return tp.width.ceilToDouble() + 1.0;
  }

  Size _layoutMultiline(BoxItem b, TextStyle style, double maxContentW) {
    final tp = TextPainter(
      text: TextSpan(text: b.text.isEmpty ? ' ' : b.text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null, // çok satır
    )..layout(maxWidth: maxContentW);
    return tp.size;
  }

  // ==== ölçüm (tek satır) ====

  // ==== gestures ====
  void _onScaleStart(ScaleStartDetails d) {
    widget.onInteract?.call(true);

    _startW = widget.box.width;
    _startH = widget.box.height;
    _startRot = widget.box.rotation;
    _lastGlobalPoint = d.focalPoint;

    _startFontSize = widget.box.fixedFontSize;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final b = widget.box;

    // klavye açık + textbox edit iken kutuyu sabit tut (panelle çakışmasın)
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final floatingEdit =
        widget.isEditing && kb > 0 && b.type == "textbox" && widget.floatOnEdit;

    if (!floatingEdit) {
      if (d.pointerCount == 1) {
        if (d.focalPointDelta.distanceSquared >= 0.25) {
          b.position += d.focalPointDelta;
        }
      }
      if (d.pointerCount >= 2) {
        if (d.scale > 0) {
          b.width = (_startW * d.scale).clamp(24.0, 4096.0).toDouble();
          b.height = (_startH * d.scale).clamp(24.0, 4096.0).toDouble();

          b.fixedFontSize = (_startFontSize * d.scale).clamp(8.0, 300.0);
        }
        b.rotation = _startRot + d.rotation;
      }
    }

    _lastGlobalPoint = d.focalPoint;

    bool over = false;
    final p = _lastGlobalPoint; // null güvenli
    if (p != null) {
      over = widget.isOverTrash(p);
    }
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
    widget.onDeselect?.call();
  }

  // ==== content ====
  Widget _buildContent(BoxItem b) {
    if (b.type == "image") {
      if (b.imageBytes == null || b.imageBytes!.isEmpty) {
        return const Text("Resim yükleniyor...", style: TextStyle(color: Colors.grey));
      }
      return SizedBox.expand(
        child: Opacity(
          opacity: b.imageOpacity.clamp(0.0, 1.0).toDouble(),
          child: Image.memory(
            b.imageBytes!,
            fit: BoxFit.cover, // alanı tamamen kapla
            gaplessPlayback: true,
          ),
        ),
      );
    }

    int getLineCount(String text, TextStyle style, double maxWidth) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: maxWidth);

      return tp.computeLineMetrics().length;
    }

    final isText = b.type == "textbox";
    final editHere = widget.isEditing && isText;
    getLineCount(
      b.text,
      TextStyle(
        fontSize: b.fixedFontSize,
        fontFamily: b.fontFamily,
        fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
        fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
        decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
      ),
      b.width - _padH * 2,
    );

    return Align(
      alignment: Alignment(
        b.align == TextAlign.left ? -1 : (b.align == TextAlign.right ? 1 : 0),
        b.vAlign == 'top' ? -1 : (b.vAlign == 'bottom' ? 1 : 0),
      ),
      child: editHere
          ? TextField(
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
                if (val.trim().isEmpty) {
                  widget.onDelete();
                  return;
                }
                // Bu edit sırasında, fontu sabit alıyoruz (auto fit değil),
                // kutunun ölçüsünü genişlik/ yükseklik ile ayarlıyoruz.
                final media = MediaQuery.of(context);
                final screen = media.size;

                // yazarken tek satır sığdığı sürece genişlet,
                // sığmazsa genişliği max yap, çok satır yüksekliği arttır
                const padW = _padH * 2;
                const padH = _padV * 2;

                // Yazarken kutu ekran içinde kalsın (kenarlarda 16px pay)
                final double maxBoxW = (screen.width - 32).clamp(24.0, 4096.0);

                final baseStyle = TextStyle(
                  fontSize: b.fixedFontSize,
                  fontFamily: b.fontFamily,
                  fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
                  fontStyle:  b.italic ? FontStyle.italic : FontStyle.normal,
                  decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
                );

                final singleLineW = _measureSingleLineWidth(b, baseStyle);
                if (singleLineW + padW <= maxBoxW) {
                  // Tek satır sığıyor → genişliği tek satıra göre ayarla, yükseklik 1 satır
                  // son harf taşmasın diye +1 ekliyoruz (zaten _measureSingleLineWidth’te var)
                  b.width  = (singleLineW + padW).clamp(24.0, 4096.0).toDouble();

                  // 1 satır yüksekliği
                  final oneLine = TextPainter(
                    text: TextSpan(text: 'M', style: baseStyle),
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                  )..layout();
                  b.height = (oneLine.height + padH).clamp(24.0, 4096.0).toDouble();
                } else {
                  // Sığmıyor → genişliği sabitle (max), çok satır yerleşimine göre yükseklik artır
                  final contentW = (maxBoxW - padW).clamp(1.0, maxBoxW);
                  final multi = _layoutMultiline(b, baseStyle, contentW);
                  b.width  = maxBoxW;
                  b.height = (multi.height + padH).clamp(24.0, 4096.0).toDouble();
                }

// display-fit hesabı güncellensin
                widget.onUpdate();
              },
              onSubmitted: (_) => widget.onSave(),
            )
          : Text(
            b.text.isEmpty ? "Metin..." : b.text,
            maxLines: null,
            softWrap: true,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: b.fixedFontSize,
              fontFamily: b.fontFamily,
              fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
              decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
              color: Color(b.textColor),
            ),
          ),
    );
  }

  // ==== resize handles ====
  List<Widget> _buildResizeHandles(BoxItem box) {
    const double s = 16;
    const double a = 32;
    final List<Widget> hs = [];

    void add(double left, double top, void Function(double dx, double dy) onDrag) {
      hs.add(Positioned(
        left: left,
        top: top,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => widget.onInteract?.call(true),
          onPanUpdate: (d) {
            onDrag(d.delta.dx, d.delta.dy);
            widget.onUpdate();
          },
          onPanEnd: (_) {
            widget.onInteract?.call(false);
            widget.onSave();
          },
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              color: const Color.fromARGB(120, 0, 0, 0),
              shape: BoxShape.circle, // %100 radius
              border: Border.all(color: Colors.white70, width: 1),
            ),
          ),
        ),
      ));
    }

    // köşeler
    add(-s / 2 + a, -s / 2 + a, (dx, dy) {
      box.width = (box.width - dx).clamp(24.0, 4096.0);
      box.height = (box.height - dy).clamp(24.0, 4096.0);
      box.position += Offset(dx, dy);
    });
    add(box.width - s / 2 - a, -s / 2 + a, (dx, dy) {
      box.width = (box.width + dx).clamp(24.0, 4096.0);
      box.height = (box.height - dy).clamp(24.0, 4096.0);
      box.position += const Offset(0, 0) + Offset(0, dy);
    });
    add(-s / 2 + a, box.height - s / 2 - a, (dx, dy) {
      box.width = (box.width - dx).clamp(24.0, 4096.0);
      box.height = (box.height + dy).clamp(24.0, 4096.0);
      box.position += Offset(dx, 0);
    });
    add(box.width - s / 2 - a, box.height - s / 2 - a, (dx, dy) {
      box.width = (box.width + dx).clamp(24.0, 4096.0);
      box.height = (box.height + dy).clamp(24.0, 4096.0);
    });

    // kenarlar
    add(box.width / 2 - s / 2, -s / 2 + a, (dx, dy) {
      box.height = (box.height - dy).clamp(24.0, 4096.0);
      box.position += Offset(0, dy);
    });
    add(box.width / 2 - s / 2, box.height - s / 2 - a, (dx, dy) {
      box.height = (box.height + dy).clamp(24.0, 4096.0);
    });
    add(-s / 2 + a, box.height / 2 - s / 2, (dx, dy) {
      box.width = (box.width - dx).clamp(24.0, 4096.0);
      box.position += Offset(dx, 0);
    });
    add(box.width - s / 2 - a, box.height / 2 - s / 2, (dx, dy) {
      box.width = (box.width + dx).clamp(24.0, 4096.0);
    });

    return hs;
  }

  // ==== inline text toolbar (opsiyonel) ====
  Widget _buildTextInlineToolbar(BoxItem b) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          height: _toolbarH,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.color_lens, size: 20),
                  onPressed: () {
                    final colors = [
                      0xFF000000,
                      0xFF2962FF,
                      0xFFD81B60,
                      0xFF2E7D32,
                      0xFFF9A825,
                      0xFFFFFFFF
                    ];
                    showModalBottomSheet(
                      context: context,
                      barrierColor: Colors.transparent,
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
                  icon:
                      Icon(Icons.format_underline, size: 20, color: b.underline ? Colors.teal : null),
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
                      },
                      onChangeEnd: (_) => widget.onSave(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Eski px kaydı görürse faktöre çevir (panel açılmadan önce çağıracağız)
  void _normalizeRadiusToFactor(BoxItem b) {
    final minSide = b.width < b.height ? b.width : b.height;
    if (minSide <= 0) return;
    if (b.borderRadius > 1.0) {
      final factor = (b.borderRadius / minSide).clamp(0.0, 0.5);
      b.borderRadius = factor;
    }
  }

  // ==== image panel ====
  Future<void> _openImageEditPanel() async {
    widget.onInteract?.call(true);
    _normalizeRadiusToFactor(widget.box); // px -> factor
    widget.onPanelOpen?.call();
    await showModalBottomSheet(
      context: context,
      barrierColor: Colors.transparent, // karartma yok
      builder: (_) {
        final b = widget.box;
        double localRadiusFactor = b.borderRadius.clamp(0.0, 0.5); // 0..0.5
        double localOpacity = b.imageOpacity;

        return StatefulBuilder(builder: (_, setSt) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Resim Ayarları", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text("Radius (%)"),
                      Expanded(
                        child: Slider(
                          value: localRadiusFactor,
                          min: 0,
                          max: 0.5,
                          onChanged: (v) {
                            setSt(() => localRadiusFactor = v);
                            b.borderRadius = v; // factor
                            widget.onUpdate();
                            widget.onSave();
                          },
                        ),
                      ),
                    ],
                  ),
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
    ).whenComplete(() {
      widget.onInteract?.call(false);
      widget.onPanelClose?.call();
    });
  }
  
  // ==== text panel ====
  Future<void> _openTextBoxEditPanel() async {
    widget.onInteract?.call(true);
    _normalizeRadiusToFactor(widget.box); // px -> factor
    widget.onPanelOpen?.call();
    await showModalBottomSheet(
      context: context,
      barrierColor: Colors.transparent, // karartma yok
      builder: (_) {
        final b = widget.box;
        double localRadiusFactor = b.borderRadius.clamp(0.0, 0.5);
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
                  const Text("Metin Kutusu Ayarları", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
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
                                color: color == localBgColor ? Colors.teal : Colors.black12,
                                width: color == localBgColor ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
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
                  Row(
                    children: [
                      const Text("Radius (%)"),
                      Expanded(
                        child: Slider(
                          value: localRadiusFactor,
                          min: 0,
                          max: 0.5,
                          onChanged: (v) {
                            setSt(() => localRadiusFactor = v);
                            b.borderRadius = v;
                            widget.onUpdate();
                            widget.onSave();
                          },
                        ),
                      ),
                    ],
                  ),
                  // --- Metin Rengi (renk çarkı ile) ---
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text("Metin Rengi"),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.color_lens),
                        label: const Text("Renk Seç"),
                        onPressed: () async {
                          Color temp = Color(b.textColor);
                          await showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Metin Rengi"),
                              content: SingleChildScrollView(
                                child: ColorPicker(
                                  pickerColor: temp,
                                  onColorChanged: (c) => temp = c,
                                  paletteType: PaletteType.hsvWithHue, // renk çarkı
                                  enableAlpha: false,
                                  displayThumbColor: true,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("İptal"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    // ignore: deprecated_member_use
                                    b.textColor = temp.value;
                                    widget.onUpdate();
                                    widget.onSave();
                                    Navigator.pop(context);
                                  },
                                  child: const Text("Seç"),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
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
    ).whenComplete(() {
      widget.onPanelClose?.call();
    });
  }


  @override
  Widget build(BuildContext context) {
    final b = widget.box;

    final media = MediaQuery.of(context);
    final kb = media.viewInsets.bottom;
    final screen = media.size;

    final floatingEdit = widget.isEditing && b.type == "textbox" && kb > 0;

    // klavye üstü konum (floatOnEdit true ise)
    const floatLeft = 16.0;
    final availableH = screen.height - kb;
    final upper = availableH - b.height - 8.0;
    final topForBox = upper < 8.0 ? 8.0 : upper;

    final showToolbar = widget.inlineToolbar && widget.isEditing && b.type == "textbox";
    final posLeft = floatingEdit && widget.floatOnEdit ? floatLeft : b.position.dx;
    final posTop = (floatingEdit && widget.floatOnEdit ? topForBox : b.position.dy) -
        (showToolbar ? (_toolbarH + 6) : 0.0);

    final double effR = _effectiveRadius(b);

    return Positioned(
      left: posLeft,
      top: posTop,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        onDoubleTap: () {
          final b = widget.box;
          b.isSelected = true; // *** her zaman seçili yap
          widget.onUpdate();
          if (b.type == "image") {
            _openImageEditPanel();
          } else {
            _openTextBoxEditPanel();
          }
        },
        onTap: () {
          final b = widget.box;
          if (b.type == "textbox") {
            widget.onSelect(true); // edit modunu aç
            // her durumda odak iste
            Future.microtask(() {
              if (!_focusNode.hasFocus) _focusNode.requestFocus();
            });
          } else {
            widget.onSelect(false);
          }
        },
        child: Transform.rotate(
          angle: (floatingEdit && widget.floatOnEdit) ? 0.0 : b.rotation,
          child: SizedBox(
            width: b.width,
            height: b.height + (showToolbar ? (_toolbarH + 6) : 0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (showToolbar)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: _buildTextInlineToolbar(b),
                  ),

                // ana kutu
                Positioned(
                  left: 0,
                  top: (showToolbar ? (_toolbarH + 6) : 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(effR),
                    child: Container(
                      width: b.width,
                      height: b.height,
                      color: b.type == "image"
                          ? Colors.transparent
                          : Color(b.backgroundColor).withAlpha(
                              (b.backgroundOpacity * 255).clamp(0, 255).round(),
                            ),
                      alignment: Alignment.center,
                      padding: b.type == "textbox"
                          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
                          : EdgeInsets.zero,
                      child: _buildContent(b),
                    ),
                  ),
                ),

                // handle'lar
                if (b.isSelected)
                  Positioned(
                    left: 0,
                    top: (showToolbar ? (_toolbarH + 6) : 0),
                    child: SizedBox(
                      width: b.width,
                      height: b.height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: b.type == "image" ? _buildResizeHandles(b) : [],
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
