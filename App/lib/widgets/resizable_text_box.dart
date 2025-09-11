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
  final void Function(BoxItem box)? onOpenPanel;

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
    this.onOpenPanel,
  });

  @override
  State<ResizableTextBox> createState() => _ResizableTextBoxState();
}

class _ResizableTextBoxState extends State<ResizableTextBox> {
  int _overTrashFrames = 0;
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  // scale/rotate/pan state
  Offset? _panSmoothed; // ✨ silme için son global dokunma
  Offset? _lastGlobalPoint;
  late Offset _startPos;
  late double _startW;
  late double _startH;
  late double _startRot; // radians

  // 💡 font-fit cache (sık ölçümde performans için)
  String? _fitKey;
  double? _fitSize;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.box.text);

    // Fokus değiştiğinde kaydet / etkileşim bildir
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        widget.onInteract?.call(true);
      } else {
        // yazı modundan çıkıldı → kaydet
        widget.onSave();
        widget.onInteract?.call(false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ResizableTextBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Dışarıdan gelen text değişmişse TextField’i senkronla (edit modunda)
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

  // ==== 1) Metni kutuya TAM sığdıran font ölçümü (genişlik+yükseklik) ====
  double _fitFontSize(BoxItem b) {
    // cache anahtarı
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

    // pratik üst sınır (fiilen sınırsız gibi davranır)
    double lo = 1.0, hi = 2000.0; // min/max istemiyorsun → çok geniş aralık
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
        maxLines: null,
      );
      tp.layout(maxWidth: b.width);
      // Hem genişlik hem de yükseklik sığmalı
      return tp.size.width <= b.width + 0.5 && tp.size.height <= b.height + 0.5;
    }

    // Binary search: en büyük sığan fontu bul
    for (int i = 0; i < 25; i++) {
      final mid = (lo + hi) / 2;
      if (fits(mid)) {
        lo = mid; // sığıyor → büyüt
      } else {
        hi = mid; // sığmıyor → küçült
      }
    }

    _fitKey = key;
    _fitSize = lo;
    return lo;
  }

  // ==== 2) Ölçekleme & Döndürme & Sürükleme ====
  void _onScaleStart(ScaleStartDetails d) {
    widget.onInteract?.call(true);
    widget.onSelect(false); // sürüklerken de seçsin

    _startPos = widget.box.position;
    _startW   = widget.box.width;
    _startH   = widget.box.height;
    _startRot = widget.box.rotation;
    _lastGlobalPoint = d.focalPoint;

    _panSmoothed = _startPos;
    _overTrashFrames = 0;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final b = widget.box;

    // 1) Tek parmakta sadece pan + yumuşatma (teleport/jitter azaltma)
    if (d.pointerCount == 1) {
      if (d.focalPointDelta.distanceSquared < 0.25) return; // ~0.5px altı hareketleri yok say
      b.position += d.focalPointDelta;
    }

    // 2) İki parmakta sadece scale + rotate (pan yok → zıplama azalır)
    if (d.pointerCount >= 2) {
      if (d.scale > 0) {
        b.width  = (_startW * d.scale).clamp(24.0, 4096.0);
        b.height = (_startH * d.scale).clamp(24.0, 4096.0);
        _fitKey = null; // font-fit cache
      }
      b.rotation = _startRot + d.rotation;
    }

    _lastGlobalPoint = d.focalPoint;

    // çöp üstünde kaç frame kalındığını say
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

    final render = context.findRenderObject() as RenderBox?;
    if (render != null) {
      final b = widget.box;

      // çoklu nokta testi
      final center       = render.localToGlobal(Offset(b.width/2, b.height/2));
      final bottomCenter = render.localToGlobal(Offset(b.width/2, b.height));
      final leftBottom   = render.localToGlobal(Offset(0, b.height));
      final rightBottom  = render.localToGlobal(Offset(b.width, b.height));

      bool hit(Offset o) => widget.isOverTrash(o);

      final over = _lastGlobalPoint != null && widget.isOverTrash(_lastGlobalPoint!);
      // hem en az 2 frame çöp üstünde kalmış ol, hem de noktalardan biri çöp içinde olsun
      if (_overTrashFrames >= 2 && over) {
        shouldDelete = true;
      }
    }

    widget.onDraggingOverTrash?.call(false);
    widget.onInteract?.call(false);

    if (shouldDelete) {
      widget.onDelete();
      return;
    }

    widget.onSave(); // bırakınca kaydet
  }

  // ==== 3) Dönen kutu ile birlikte dönen handle'lar ====
  List<Widget> _buildResizeHandles(BoxItem box) {
    const double handleSize = 32;
    final List<Widget> handles = [];

    void addHandle(
      double left,
      double top,
      Color color,
      void Function(double dx, double dy) onResize,
    ) {
      handles.add(Positioned(
        left: left,
        top: top,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) {
            widget.onInteract?.call(true);
            widget.onSelect(false); // <<< EKLE (sürükleyince de seçili kalsın)
          },
          onPanUpdate: (details) {
            onResize(details.delta.dx, details.delta.dy);
            _fitKey = null; // boyut değişti → font-fit cache sıfırla
            widget.onUpdate();
          },
          onPanEnd: (_) {
            widget.onSave();
            widget.onInteract?.call(false);
          },
          child: Container(
            width: handleSize,
            height: handleSize,
            color: color,
          ),
        ),
      ));
    }

    // köşeler (kırmızı)
    addHandle(-handleSize / 2 + 16, -handleSize / 2 + 16, Colors.red, (dx, dy) {
      box.width = (box.width - dx).clamp(24.0, 4096.0);
      box.height = (box.height - dy).clamp(24.0, 4096.0);
      box.position += Offset(dx, dy);
    });
    addHandle(box.width - handleSize / 2 - 16, -handleSize / 2 + 16, Colors.red, (dx, dy) {
      box.width = (box.width + dx).clamp(24.0, 4096.0);
      box.height = (box.height - dy).clamp(24.0, 4096.0);
      box.position += Offset(0, dy);
    });
    addHandle(-handleSize / 2 + 16, box.height - handleSize / 2 - 16, Colors.red, (dx, dy) {
      box.width = (box.width - dx).clamp(24.0, 4096.0);
      box.height = (box.height + dy).clamp(24.0, 4096.0);
      box.position += Offset(dx, 0);
    });
    addHandle(
      box.width - handleSize / 2 - 16, box.height - handleSize / 2 - 16,
      Colors.red,
      (dx, dy) {
        box.width = (box.width + dx).clamp(24.0, 4096.0);
        box.height = (box.height + dy).clamp(24.0, 4096.0);
      },
    );

    // kenarlar (mavi)
    addHandle(box.width / 2 - handleSize / 2, -handleSize / 2 + 16, Colors.blue, (dx, dy) {
      box.height = (box.height - dy).clamp(24.0, 4096.0);
      box.position += Offset(0, dy);
    });
    addHandle(
      box.width / 2 - handleSize / 2, box.height - handleSize / 2 - 16,
      Colors.blue,
      (dx, dy) {
        box.height = (box.height + dy).clamp(24.0, 4096.0);
      },
    );
    addHandle(-handleSize / 2 + 16, box.height / 2 - handleSize / 2, Colors.blue, (dx, dy) {
      box.width = (box.width - dx).clamp(24.0, 4096.0);
      box.position += Offset(dx, 0);
    });
    addHandle(
      box.width - handleSize / 2 - 16, box.height / 2 - handleSize / 2,
      Colors.blue,
      (dx, dy) {
        box.width = (box.width + dx).clamp(24.0, 4096.0);
      },
    );

    return handles;
  }

  Size _measureSingleLine(BoxItem b) {
    final tp = TextPainter(
      text: TextSpan(
        text: b.text.isEmpty ? 'Metin...' : b.text,
        style: TextStyle(
          fontSize: (b.autoFontSize ? _fitFontSize(b) : b.fixedFontSize).clamp(6, 2000),
          fontFamily: b.fontFamily,
          fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
          fontStyle:  b.italic ? FontStyle.italic : FontStyle.normal,
          decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    // sağ-sol 12px, üst-alt 6px nefes payı
    return Size(tp.width + 24, tp.height + 12);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.box;
    final media = MediaQuery.of(context);
    final kb = media.viewInsets.bottom;
    final screen = media.size;
    final double maxWWhileEditing = screen.width - 32; // 16px sağ-sol marj
    final double maxHWhileEditing = (screen.height - kb) * 0.35 /* keyfi bir üst sınır */;
    double desiredW = b.width;
    double desiredH = b.height;
    if (b.type == "textbox") {
      final s = _measureSingleLine(b);
      desiredW = s.width;
      desiredH = s.height;
    }

    if (widget.isEditing && kb > 0) {
      b.width  = desiredW.clamp(24.0, maxWWhileEditing);
      b.height = desiredH.clamp(24.0, maxHWhileEditing);
    } else {
      if (desiredW > b.width)  b.width  = desiredW;
      if (desiredH > b.height) b.height = desiredH;
    }

    double left = b.position.dx;
    double top  = b.position.dy;
    const double toolbarH = 48;
    
    final bool floatingEdit = widget.isEditing && kb > 0;

    // klavye varken kutuyu ekranın altına sabitle (toolbar’ı da hesapla)
    if (floatingEdit) {
      left = 16;
      top  = (screen.height - kb) - b.height - toolbarH - 12;
      if (top < 12) top = 12; // güvenlik marjı
    }

    // Transform.rotate artık Container + Handle'ları birlikte sarıyor
    return Positioned(
      left: b.position.dx,
      top: b.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        onDoubleTap: () {
          if (widget.onOpenPanel != null) {
            widget.onOpenPanel!(widget.box);
          } else {
            if (widget.box.type == "image") {
              _openImageEditPanel();
            } else {
              _openTextBoxEditPanel();
            }
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
          angle: b.rotation, // radians
          child: SizedBox(
            width: b.width,
            height: b.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // yazı toolbar’ı (sadece editte ve textbox iken)
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

                // inline toolbar (varsa) buradan sonra…

                // handle’lar
                if (b.isSelected) ..._buildResizeHandles(b),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
                final colors = [0xFF000000,0xFF2962FF,0xFFD81B60,0xFF2E7D32,0xFFF9A825,0xFFFFFFFF];
                showModalBottomSheet(
                  context: context,
                  builder: (_) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 8, runSpacing: 8,
                        children: colors.map((c) => GestureDetector(
                          onTap: (){
                            b.textColor = c;
                            widget.onUpdate();
                            widget.onSave();
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: Color(c),
                              border: Border.all(color: Colors.black12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                  ),
                );
              },
              child: const Icon(Icons.color_lens, size: 20),
            ),

            IconButton(
              icon: Icon(Icons.format_bold, size: 20, color: b.bold ? Colors.teal : null),
              onPressed: () { b.bold = !b.bold; widget.onUpdate(); widget.onSave(); },
            ),
            IconButton(
              icon: Icon(Icons.format_italic, size: 20, color: b.italic ? Colors.teal : null),
              onPressed: () { b.italic = !b.italic; widget.onUpdate(); widget.onSave(); },
            ),
            IconButton(
              icon: Icon(Icons.format_underline, size: 20, color: b.underline ? Colors.teal : null),
              onPressed: () { b.underline = !b.underline; widget.onUpdate(); widget.onSave(); },
            ),

            const VerticalDivider(),

            // yatay hizalar
            IconButton(
              icon: const Icon(Icons.format_align_left, size: 20),
              onPressed: () { b.align = TextAlign.left; widget.onUpdate(); widget.onSave(); },
            ),
            IconButton(
              icon: const Icon(Icons.format_align_center, size: 20),
              onPressed: () { b.align = TextAlign.center; widget.onUpdate(); widget.onSave(); },
            ),
            IconButton(
              icon: const Icon(Icons.format_align_right, size: 20),
              onPressed: () { b.align = TextAlign.right; widget.onUpdate(); widget.onSave(); },
            ),

            const VerticalDivider(),

            // dikey hizalar
            IconButton(
              icon: const Icon(Icons.vertical_align_top, size: 20),
              onPressed: () { b.vAlign = 'top'; widget.onUpdate(); widget.onSave(); },
            ),
            IconButton(
              icon: const Icon(Icons.vertical_align_center, size: 20),
              onPressed: () { b.vAlign = 'middle'; widget.onUpdate(); widget.onSave(); },
            ),
            IconButton(
              icon: const Icon(Icons.vertical_align_bottom, size: 20),
              onPressed: () { b.vAlign = 'bottom'; widget.onUpdate(); widget.onSave(); },
            ),

            const VerticalDivider(),

            // font auto/fixed toggle
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
                  min: 6, max: 200,
                  onChanged: (v) { b.fixedFontSize = v; widget.onUpdate(); },
                  onChangeEnd: (_) => widget.onSave(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openImageEditPanel() {
    final b = widget.box;
    showModalBottomSheet(
      context: context,
      builder: (_) {
        double tmpRadius = b.borderRadius;
        double tmpOpacity = b.imageOpacity;
        return StatefulBuilder(builder: (_, setSt) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Resim Ayarları", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  // Radius
                  Row(
                    children: [
                      const Text("Radius"),
                      Expanded(
                        child: Slider(
                          value: tmpRadius,
                          min: 0, max: 64,
                          onChanged: (v) => setSt(() => tmpRadius = v),
                        ),
                      ),
                    ],
                  ),
                  // Opacity
                  Row(
                    children: [
                      const Text("Opacity"),
                      Expanded(
                        child: Slider(
                          value: tmpOpacity,
                          min: 0, max: 1,
                          onChanged: (v) => setSt(() => tmpOpacity = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Z-index kontrolleri
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: const Text("İptal"),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        child: const Text("Uygula"),
                        onPressed: () {
                          b.borderRadius = tmpRadius;
                          b.imageOpacity = tmpOpacity;
                          widget.onUpdate();
                          widget.onSave();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _openTextBoxEditPanel() {
    final b = widget.box;
    showModalBottomSheet(
      context: context,
      builder: (_) {
        double tmpRadius = b.borderRadius;
        double tmpBgOpacity = b.backgroundOpacity;
        int tmpBgColor = b.backgroundColor;

        Color cFrom(int v)=>Color(v);
        List<int> swatches = [0xFFFFFFFF,0xFFF8F9FA,0xFFFFF3CD,0xFFE3F2FD,0xFFE8F5E9,0xFFFFEBEE,0xFF212121];

        return StatefulBuilder(builder: (_, setSt) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Metin Kutusu Ayarları", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // Background color palette
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: swatches.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final color = swatches[i];
                        return GestureDetector(
                          onTap: () => setSt(() => tmpBgColor = color),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: cFrom(color),
                              border: Border.all(
                                color: color == tmpBgColor ? Colors.teal : Colors.black12,
                                width: color == tmpBgColor ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Background opacity
                  Row(
                    children: [
                      const Text("BG Opacity"),
                      Expanded(
                        child: Slider(
                          value: tmpBgOpacity,
                          min: 0, max: 1,
                          onChanged: (v) => setSt(() => tmpBgOpacity = v),
                        ),
                      ),
                    ],
                  ),
                  // Radius
                  Row(
                    children: [
                      const Text("Radius"),
                      Expanded(
                        child: Slider(
                          value: tmpRadius,
                          min: 0, max: 64,
                          onChanged: (v) => setSt(() => tmpRadius = v),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  // Z-index controls
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: const Text("İptal"),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        child: const Text("Uygula"),
                        onPressed: () {
                          b.borderRadius = tmpRadius;
                          b.backgroundOpacity = tmpBgOpacity;
                          b.backgroundColor = tmpBgColor;
                          widget.onUpdate();
                          widget.onSave();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildContent(BoxItem b) {
    if (b.type == "image") {
      if (b.imageBytes == null || b.imageBytes!.isEmpty) {
        return const Text("Resim yükleniyor...", style: TextStyle(color: Colors.grey));
      }
      return Opacity(
        opacity: b.imageOpacity.clamp(0.0, 1.0).toDouble(),
        child: SizedBox.expand(
          child: Image.memory(
            b.imageBytes!,
            fit: BoxFit.cover,      // taşanı kırpar
            gaplessPlayback: true,
          ),
        ),
      );
    }
    // text
    final fitted = b.autoFontSize ? _fitFontSize(b) : b.fixedFontSize;
    if (widget.isEditing) {
      return Align(
      alignment: Alignment(
        b.align == TextAlign.left ? -1 :
        b.align == TextAlign.right ? 1 : 0,
        b.vAlign == 'top' ? -1 : b.vAlign == 'bottom' ? 1 : 0,
      ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          maxLines: 1,
          textAlign: b.align,
          decoration: const InputDecoration(border: InputBorder.none, hintText: "Metin..."),
          style: TextStyle(
            fontSize: (b.autoFontSize ? _fitFontSize(b) : b.fixedFontSize).clamp(6, 2000),
            fontFamily: b.fontFamily,
            fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
            fontStyle:  b.italic ? FontStyle.italic : FontStyle.normal,
            decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
            color: Color(b.textColor),
          ),
          onChanged: (val) {
            b.text = val;

            // ✨ gereken tek-satır genişliği/ yüksekliği kadar kutuyu büyüt
            final tp = TextPainter(
              text: TextSpan(
                text: b.text.isEmpty ? 'Metin...' : b.text,
                style: TextStyle(
                  fontSize: (_fitFontSize(b)).clamp(12, 2000),
                  fontFamily: b.fontFamily,
                  fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
                  fontStyle:  b.italic ? FontStyle.italic : FontStyle.normal,
                  decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            )..layout();

            // padding payı (sağ/sol + biraz nefes)
            final desiredW = tp.width + 24;
            final desiredH = tp.height + 12;

            if (desiredW > b.width)  b.width  = desiredW;
            if (desiredH > b.height) b.height = desiredH;

            _fitKey = null; // ölçüm cache reset
            widget.onUpdate();      // UI’ı güncelle
            // NOT: kaydetme yok; odak kaybedince kaydolacak (mevcut mantık)
          },
          onSubmitted: (_) => widget.onSave(), // enter’a basarsa kaydet
        ),
      );
    } else {
      return Align(
        alignment: Alignment(
          b.align == TextAlign.left ? -1 :
          b.align == TextAlign.right ? 1 : 0,
          b.vAlign == 'top' ? -1 : b.vAlign == 'bottom' ? 1 : 0,
        ),
        child: Text(
          b.text.isEmpty ? "Metin..." : b.text,
          maxLines: 1,
          overflow: TextOverflow.visible,
          softWrap: false,
          style: TextStyle(
            fontSize: fitted,
            fontFamily: b.fontFamily,
            fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
            decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
            color: Color(b.textColor),
          ),
        ),
      );
    }
  }
}
