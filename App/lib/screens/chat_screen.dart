import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:async';
import '../models/box_item.dart';
import '../widgets/resizable_text_box.dart';

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String otherUserId;
  final String otherUsername;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUsername,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? _selectedId;
  bool _isInteracting = false;
  final bool _isPanelOpen = false;
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> _sub;

  final CollectionReference<Map<String, dynamic>> messages =
      FirebaseFirestore.instance.collection("messages");

  final List<BoxItem> _boxes = [];
  final GlobalKey _trashKey = GlobalKey();
  final GlobalKey _fontBtnKey = GlobalKey();
  bool _draggingOverTrash = false;
  BoxItem? _editingBox;

  // Overlay editör
  BoxItem? _editingTextBox;
  final ScrollController _toolbarScroll = ScrollController();
  final GlobalKey _overlayEditorKey = GlobalKey();
  final GlobalKey _overlayToolbarKey = GlobalKey();
  final FocusNode _overlayFocus = FocusNode();
  TextEditingController? _overlayCtrl;

  int _uiEpoch = 0; // RTB'leri cache-bust etmek için

  String getConversationId() {
    final ids = [widget.currentUserId, widget.otherUserId]..sort();
    return ids.join("_");
  }

  bool get _isTypingOverlayVisible {
    return _editingTextBox != null && _editingTextBox!.type == "textbox";
  }

  @override
  void initState() {
    super.initState();

    _sub = messages
        .where("conversationId", isEqualTo: getConversationId())
        .snapshots()
        .listen((snapshot) {
      final incoming =
          snapshot.docs.map((d) => BoxItem.fromJson(d.data())).toList();

      incoming.sort((a, b) => a.z.compareTo(b.z));

      List<BoxItem> merged;
      if (_isInteracting && _selectedId != null) {
        final localMap = {for (final b in _boxes) b.id: b};
        merged = incoming.map((nb) {
          if (nb.id == _selectedId && localMap[_selectedId!] != null) {
            return localMap[_selectedId!]!;
          }
          return nb;
        }).toList();
      } else {
        merged = incoming;
      }

      merged.sort((a, b) => a.z.compareTo(b.z));
      for (final b in merged) {
        b.isSelected = (b.id == _selectedId);
      }

      if (!mounted) return;
      setState(() {
        _boxes
          ..clear()
          ..addAll(merged);
      });
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _overlayFocus.dispose();
    _overlayCtrl?.dispose();
    super.dispose();
  }

  // ==== helpers ====
  bool _hit(GlobalKey key, Offset gp) {
    final rb = key.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return false;
    final p = rb.localToGlobal(Offset.zero);
    final r = Rect.fromLTWH(p.dx, p.dy, rb.size.width, rb.size.height);
    return r.contains(gp);
  }

  double _effectiveRadiusFor(BoxItem b) {
    final minSide = b.width < b.height ? b.width : b.height;
    final r = b.borderRadius;
    final asPx = (r <= 1.0) ? (r * minSide) : r;
    final maxR = minSide / 2;
    return asPx.clamp(0, maxR).toDouble();
  }

  // ===== CRUD =====
  Future<void> _addBox() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final newBox = BoxItem(
      id: now.toString(),
      position: const Offset(150, 150),
      type: "textbox",
      text: "",
      fontSize: 24, // başlangıç için 24
      width: 120,
      height: 48,
      z: now,
      // metin varsayılanları:
      align: TextAlign.center,
      vAlign: 'center',
      autoFontSize: true,       // auto mod açık
      fixedFontSize: 24.0,      // auto açıkken değer saklı ama min 24 kuralına uyacağız
    );

    setState(() {
      for (var b in _boxes) {
        b.isSelected = false;
      }
      _overlayCtrl?.dispose();
      _overlayCtrl = null;
      newBox.isSelected = true;
      _boxes.add(newBox);
      _editingBox = null;
      _selectedId = newBox.id;
      _editingTextBox = newBox;
    });

    await messages.doc(newBox.id).set({
      ...newBox.toJson(
        getConversationId(),
        widget.currentUserId,
        widget.otherUserId,
      ),
      "createdAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Uint8List> _compressToFirestoreLimit(Uint8List data) async {
    final img.Image? decoded = img.decodeImage(data);
    if (decoded == null) return data;

    img.Image resized = decoded;
    const int maxSide = 1280;
    final int maxOfWH =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    if (maxOfWH > maxSide) {
      resized = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? maxSide : null,
        height: decoded.height > decoded.width ? maxSide : null,
        interpolation: img.Interpolation.linear,
      );
    }

    int quality = 85;
    Uint8List jpg = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    while (jpg.lengthInBytes > 900 * 1024 && quality > 40) {
      quality -= 10;
      jpg = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    }
    return jpg;
  }

  Future<void> _addImageBox() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    Uint8List bytes = await picked.readAsBytes();
    bytes = await _compressToFirestoreLimit(bytes);

    // doğal boyutları bul ve ekrana sığdır
    final decoded = img.decodeImage(bytes);
    double w = 240, h = 180;
    if (decoded != null) {
      w = decoded.width.toDouble();
      h = decoded.height.toDouble();
      // ignore: use_build_context_synchronously
      final screen = MediaQuery.of(context).size;
      final maxW = screen.width * 0.8;
      final maxH = screen.height * 0.5;
      final scale = [maxW / w, maxH / h, 1.0].reduce((a, b) => a < b ? a : b);
      if (scale < 1.0) {
        w *= scale;
        h *= scale;
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final newBox = BoxItem(
      id: now.toString(),
      position: const Offset(100, 100),
      width: w,
      height: h,
      type: "image",
      imageBytes: bytes,
      z: now,
    );

    setState(() {
      for (var b in _boxes) {
        b.isSelected = false;
      }
      newBox.isSelected = true;
      _boxes.add(newBox);
      _editingBox = null;
      _selectedId = newBox.id;
    });

    await messages.doc(newBox.id).set({
      ...newBox.toJson(
        getConversationId(),
        widget.currentUserId,
        widget.otherUserId,
      ),
      "createdAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _removeBox(BoxItem box) async {
    setState(() {
      if (_editingBox == box) _editingBox = null;
      _boxes.remove(box);
      if (_selectedId == box.id) _selectedId = null;
    });
    await messages.doc(box.id).delete();
  }

  Future<void> _updateBox(BoxItem box) async {
    await messages.doc(box.id).set({
      ...box.toJson(
        getConversationId(),
        widget.currentUserId,
        widget.otherUserId,
      ),
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  bool _isOverTrash(Offset position) {
    final renderBox = _trashKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return false;
    final trashPos = renderBox.localToGlobal(Offset.zero);
    final trashSize = renderBox.size;
    final rect = Rect.fromLTWH(trashPos.dx, trashPos.dy, trashSize.width, trashSize.height)
        .inflate(32.0);
    return rect.contains(position);
  }

  void _selectBox(BoxItem box, {bool edit = false}) {
    setState(() {
      for (var b in _boxes) {
        b.isSelected = false;
      }
      _editingBox = edit ? box : null;
      box.z = DateTime.now().millisecondsSinceEpoch;
    });
    _updateBox(box);
  }

  int countLines(String text, TextStyle style, double maxWidth) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    final lines = tp.computeLineMetrics();

    // sadece gerçek satırları say
    return lines.where((m) => m.width > 0).length;
  }
  int countLinesManual(String text) {
    return text.split('\n').length;
  }

  // ======================================================
  // ==============  TEXTBOX ÖLÇÜM / FONT-FIT  ============
  // ======================================================
  double _fitFontToConstraint({
    required String text,
    required double maxW,
    required double maxH,
    required TextStyle base,
    required int maxLines,
    required double minFs,
    required double maxFs,
  }) {
    final String measureText = (text.isEmpty ? ' ' : text);

    bool fits(double fs) {
      final tp = TextPainter(
        text: TextSpan(text: measureText, style: base.copyWith(fontSize: fs)),
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
      )..layout(maxWidth: maxW);
      return tp.size.width <= maxW + 0.5 &&
             tp.size.height <= maxH + 0.5 &&
             !tp.didExceedMaxLines;
    }

    double lo = minFs, hi = maxFs;
    for (int i = 0; i < 22; i++) {
      final mid = (lo + hi) / 2;
      if (fits(mid)) {
        lo = mid;  // sığıyor, büyüt
      } else {
        hi = mid;  // sığmıyor, küçült
      }
    }
    return lo;
  }

  // Belirtilen fs ile gerçek boyutu ölç (maxLines & softWrap=false düşüncesiyle)
  Size _measureText({
    required String text,
    required double maxW,
    required TextStyle style,
    required int maxLines,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    )..layout(maxWidth: maxW);
    return tp.size;
  }

  int _lineCountFromText(String t) => '\n'.allMatches(t).length + 1;

  // Yazma modundan çıkarken textbox’ı kurallara göre ayarla ve kaydet
  void _saveAndCloseEditor() {
    final b = _editingTextBox;
    if (b == null) return;

    const padH = 12.0, padV = 8.0;

    final text = b.text;
    final hasNewline = text.contains('\n');
    final maxLines = hasNewline ? 2 : 1;

    // base style (font ailesi/bold/italic/underline vs korunuyor)
    final base = TextStyle(
      fontFamily: b.fontFamily,
      fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
      decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
      color: Color(b.textColor),
    );

    // AUTO mu FIXED mi?
    double minFs, maxFs;
    if (b.autoFontSize) {
      minFs = 24.0;
      maxFs = 24.0;
    } else {
      // Fixed: 24..48 arası
      minFs = 24.0;
      maxFs = 24.0;
    }

    const double hugeW = 100000;

    double fs;
    if (b.autoFontSize) {
      // min 24, üst sınır 200 — kutu genişleyerek sığdırır.
      fs = minFs;
    } else {
      fs = b.fixedFontSize.clamp(minFs, maxFs);
    }

    // Gerçek metin boyutunu ölç (tek satır veya 2 satır)
    final size = _measureText(
      text: text,
      maxW: hugeW,
      style: base.copyWith(fontSize: fs),
      maxLines: maxLines,
    );

    // Kutu ölçüleri: metin + padding
    //final lineNum = countLines(text, base.copyWith(fontSize: fs), 100);
    final lineNum = countLinesManual(text);
    final newW = size.width + padH * 2 + 32;
    final newH = size.height + padV * 2 + ((lineNum - 1) * 32);

    setState(() {
      b.width = newW;
      b.height = newH;
      b.fixedFontSize = fs; // fixed modda slider’dan seçilmiş olabilir, auto’da min 24 zaten
      b.isSelected = true;  // seçim açık kalsın
      _selectedId = b.id;
      _editingTextBox = null;
      _uiEpoch++;
    });

    _updateBox(b);
    FocusScope.of(context).unfocus();
  }

  // ==== OVERLAY (YAZMA MODU) ====
  Widget _buildTypingEditor() {
    final b = _editingTextBox!;
    final screen = MediaQuery.of(context).size;

    // Yazma modunda kutu ekranı aşmamalı → maxW = ekran - 32
    final double maxW = screen.width - 32;
    // Maks 2 satır yüksekliği (24pt * 2 + padding) kadar göstereceğiz
    const padH = 12.0, padV = 8.0;
    const double maxLineFs = 24.0;
    const double oneLineH = (maxLineFs * 1.0 * 1.2); // yaklaşık line-height
    const double maxContentH = oneLineH * 100; // en fazla 2 satır
    const double maxH = maxContentH + padV * 2 + 32;

    // controller
    _overlayCtrl ??= TextEditingController(text: b.text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_overlayFocus.hasFocus) {
        _overlayFocus.requestFocus();
      }
    });

    final textNow = _overlayCtrl!.text;
    final hasNewline = textNow.contains('\n');
    _lineCountFromText(textNow);
    // Return’a basılmadıkça tek satır; varsa en fazla 2 satır
    final maxLines = hasNewline ? 2 : 1;

    // Yazma modunda font aralığı 12..24
    const minFs = 24.0;
    const maxFs = 24.0;

    final base = TextStyle(
      fontFamily: b.fontFamily,
      fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
      decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
      color: Color(b.textColor),
    );

    // fontu sığdır:
    final fs = _fitFontToConstraint(
      text: textNow,
      maxW: maxW - padH * 2,
      maxH: maxH - padV * 2,
      base: base,
      maxLines: maxLines,
      minFs: minFs,
      maxFs: maxFs,
    );

    // gerçek ölçüm:
    final measured = _measureText(
      text: textNow,
      maxW: maxW - padH * 2,
      style: base.copyWith(fontSize: fs),
      maxLines: maxLines,
    );

    //final lineNum = countLines(textNow, base.copyWith(fontSize: fs), 100);
    final lineNum = countLinesManual(textNow);
    final boxW = (measured.width + padH * 2 + 32);
    final boxH = (measured.height + padV * 2 + ((lineNum - 1) * 32));

    return Container(
      key: _overlayEditorKey,
      width: boxW,
      height: boxH,
      padding: const EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: Color(b.backgroundColor),
        borderRadius: BorderRadius.circular(_effectiveRadiusFor(b)),
      ),
      child: TextField(
        controller: _overlayCtrl,
        focusNode: _overlayFocus,
        autofocus: true,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        maxLines: null,
        minLines: 1,
        textAlign: b.align,
        textAlignVertical: TextAlignVertical.center,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
        ),
        style: base.copyWith(fontSize: fs),
        onChanged: (v) {
          b.text = v;

          final hasNL = v.contains('\n');
          final mLines = hasNL ? 2 : 1;

          final fitFs = _fitFontToConstraint(
            text: v,
            maxW: maxW - padH * 2,
            maxH: maxH - padV * 2,
            base: base,
            maxLines: mLines,
            minFs: minFs,
            maxFs: maxFs,
          );

          final s = _measureText(
            text: v,
            maxW: maxW - padH * 2,
            style: base.copyWith(fontSize: fitFs),
            maxLines: mLines,
          );

          setState(() {
            // Geçici olarak overlay kutusunu da güncelliyoruz (görselde)
            b.width = s.width + padH * 2;
            b.height = s.height + padV * 2;
            b.fixedFontSize = fitFs;
          });
        },
        onEditingComplete: _saveAndCloseEditor,
      ),
    );
  }

  // ==== üstteki toolbar ====

  Widget _buildFixedTextToolbar(BoxItem b) {
    final screen = MediaQuery.of(context).size;
    return Material(
      key: _overlayToolbarKey,
      elevation: 6,
      color: Colors.white,
      child: SizedBox(
        height: 48,
        width: screen.width,
        child: SingleChildScrollView(
          controller: _toolbarScroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.format_bold, size: 20, color: b.bold ? Colors.teal : null),
                  onPressed: () {
                    setState(() => b.bold = !b.bold);
                    _updateBox(b);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.format_italic, size: 20, color: b.italic ? Colors.teal : null),
                  onPressed: () {
                    setState(() => b.italic = !b.italic);
                    _updateBox(b);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.format_underline, size: 20, color: b.underline ? Colors.teal : null),
                  onPressed: () {
                    setState(() => b.underline = !b.underline);
                    _updateBox(b);
                  },
                ),
                const VerticalDivider(width: 12),
                IconButton(
                  icon: const Icon(Icons.format_align_left, size: 20),
                  onPressed: () {
                    setState(() => b.align = TextAlign.left);
                    _updateBox(b);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.format_align_center, size: 20),
                  onPressed: () {
                    setState(() => b.align = TextAlign.center);
                    _updateBox(b);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.format_align_right, size: 20),
                  onPressed: () {
                    setState(() => b.align = TextAlign.right);
                    _updateBox(b);
                  },
                ),
                const VerticalDivider(width: 12),
                InkWell(
                  key: _fontBtnKey,
                  onTap: () async {
                    final ctx = _fontBtnKey.currentContext;
                    if (ctx == null) return;
                    final rb = ctx.findRenderObject() as RenderBox;
                    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                    final btn = rb.localToGlobal(Offset.zero, ancestor: overlay);
                    final pos = RelativeRect.fromLTRB(
                      btn.dx,
                      btn.dy - 220,
                      overlay.size.width - (btn.dx + rb.size.width),
                      overlay.size.height - btn.dy,
                    );

                    final pick = await showMenu<String>(
                      context: context,
                      position: pos,
                      items: const [
                        PopupMenuItem(value: "Roboto", child: Text("Roboto")),
                        PopupMenuItem(value: "Arial", child: Text("Arial")),
                        PopupMenuItem(value: "Times New Roman", child: Text("Times New Roman")),
                        PopupMenuItem(value: "Courier New", child: Text("Courier New")),
                      ],
                    );
                    if (pick != null) {
                      setState(() => _editingTextBox!.fontFamily = pick);
                      _updateBox(_editingTextBox!);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.font_download, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boxesSorted = [..._boxes]..sort((a, b) => a.z.compareTo(b.z));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUsername),
        actions: [
          IconButton(icon: const Icon(Icons.add_box), onPressed: _addBox),
          IconButton(icon: const Icon(Icons.image), onPressed: _addImageBox),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (d) {
          if (_isTypingOverlayVisible) {
            final gp = d.globalPosition;
            if (_hit(_overlayToolbarKey, gp) || _hit(_overlayEditorKey, gp)) return;
            _saveAndCloseEditor();
          }
        },
        onTap: () {
          if (_isPanelOpen) return;
          if (_editingTextBox != null) return;
          if (_isTypingOverlayVisible) return;
          FocusScope.of(context).unfocus();
          setState(() {
            for (var b in boxesSorted) {
              b.isSelected = false;
            }
            _editingBox = null;
            _selectedId = null;
          });
        },
        child: Stack(
          children: [
            // Canvas
            ...boxesSorted.map((box) {
              String? _lastTapId;
              DateTime? _lastTapTime;
              return ResizableTextBox(
                key: ValueKey('${box.id}#$_uiEpoch'),
                box: box,
                isEditing: _editingBox == box,
                onUpdate: () => setState(() {}),
                onSave: () => _updateBox(box),
                
                onSelect: (edit) {
                  final now = DateTime.now();
                  final isDoubleTap = (_lastTapId == box.id &&
                      _lastTapTime != null &&
                      now.difference(_lastTapTime!) < const Duration(milliseconds: 400));

                  _lastTapId = box.id;
                  _lastTapTime = now;

                  setState(() {
                    for (var b in _boxes) b.isSelected = false;
                    box.isSelected = true;
                    _selectedId = box.id;
                  });

                  if (isDoubleTap) {
                    // Çift tık → sadece resize handles aktif (edit yok)
                    _editingBox = null;
                    _editingTextBox = null;
                  } else {
                    _selectBox(box, edit: edit);
                    if (edit && box.type == "textbox") {
                      if (_overlayCtrl == null) {
                        _overlayCtrl = TextEditingController(text: box.text);
                      } else {
                        _overlayCtrl!.text = box.text;
                      }
                      _overlayCtrl!.selection = TextSelection.collapsed(
                        offset: _overlayCtrl!.text.length,
                      );
                      setState(() => _editingTextBox = box);
                    }
                  }
                },
                onDeselect: () {
                  setState(() {
                    box.isSelected = false;
                    if (_selectedId == box.id) _selectedId = null;
                  });
                  _updateBox(box);
                },
                onDelete: () => _removeBox(box),
                isOverTrash: _isOverTrash,
                onDraggingOverTrash: (isOver) => setState(() => _draggingOverTrash = isOver),
                onInteract: (active) {
                  setState(() => _isInteracting = active);
                },
                onTextFocusChange: (hasFocus, bx) {
                  setState(() {
                    _editingBox = hasFocus ? bx : null;
                    _editingTextBox = hasFocus ? bx : null;
                    if (!hasFocus) {
                      _selectedId = null;
                      for (final b in _boxes) {
                        b.isSelected = false;
                      }
                    }
                  });
                  if (!hasFocus) _updateBox(bx);
                },
                inlineToolbar: false,
                floatOnEdit: false,
                useExternalEditor: false,
              );
            }),

            // === Yazma Overlay + Toolbar ===
            if (_isTypingOverlayVisible) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: _saveAndCloseEditor,
                  // ignore: deprecated_member_use
                  child: Container(color: Colors.black.withOpacity(0.8)),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Center(child: _buildTypingEditor()),
                        ),
                        if (_editingTextBox != null) _buildFixedTextToolbar(_editingTextBox!),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Çöp alanı
            if (_isInteracting && !_isTypingOverlayVisible)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  key: _trashKey,
                  height: 100,
                  color: _draggingOverTrash
                      // ignore: deprecated_member_use
                      ? Colors.red.withOpacity(0.5)
                      // ignore: deprecated_member_use
                      : Colors.red.withOpacity(0.2),
                  child: const Center(
                    child: Icon(Icons.delete, size: 40, color: Colors.red),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
