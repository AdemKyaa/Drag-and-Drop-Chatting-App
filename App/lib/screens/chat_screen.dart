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
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> _sub;

  final CollectionReference<Map<String, dynamic>> messages =
      FirebaseFirestore.instance.collection("messages");

  final List<BoxItem> _boxes = [];
  final GlobalKey _trashKey = GlobalKey();
  final GlobalKey _fontBtnKey = GlobalKey();
  bool _draggingOverTrash = false;
  BoxItem? _editingBox;

  // === Overlay editör (klavye üstünde) ===
  BoxItem? _editingTextBox;
  final ScrollController _toolbarScroll = ScrollController();
  final GlobalKey _overlayEditorKey = GlobalKey();
  final GlobalKey _overlayToolbarKey = GlobalKey();
  final FocusNode _overlayFocus = FocusNode();
  TextEditingController? _overlayCtrl;

  String getConversationId() {
    final ids = [widget.currentUserId, widget.otherUserId]..sort();
    return ids.join("_");
  }

  bool get _isTypingOverlayVisible {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return _editingTextBox != null &&
        _editingTextBox!.type == "textbox";
  }

  @override
  void initState() {
    super.initState();

    _sub = messages
        .where("conversationId", isEqualTo: getConversationId())
        .orderBy('z')
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

  // ===== Helpers for overlay tap detection =====
  bool _hit(GlobalKey key, Offset gp) {
    final rb = key.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return false;
    final p = rb.localToGlobal(Offset.zero);
    final r = Rect.fromLTWH(p.dx, p.dy, rb.size.width, rb.size.height);
    return r.contains(gp);
  }

  int _uiEpoch = 0; // RTB'leri force-rebuild etmek için

  void _saveAndCloseEditor() {
    final b = _editingTextBox;
    if (b == null) return;
    setState(() {
      _selectedId = b.id;
      b.isSelected = true;        // kutu seçili kalsın
      _editingTextBox = null;     // yazma modu kapansın
      // Fit cache’lerini yok etmek için RTB key’ini farklılaştıracağız
      _uiEpoch++;
    });
    _updateBox(b);
    FocusScope.of(context).unfocus(); // metin seçimi/odak kapansın
  }

  // ===== CRUD =====
  Future<void> _addBox() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final newBox = BoxItem(
      id: now.toString(),
      position: const Offset(150, 150),
      z: now,
    );

    setState(() {
      for (var b in _boxes) b.isSelected = false;
      newBox.isSelected = true;
      _boxes.add(newBox);
      _editingBox = null;
      _selectedId = newBox.id;
    });

    // doc id = box.id (eşzamanlılık için tekil)
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

    final now = DateTime.now().millisecondsSinceEpoch;
    final newBox = BoxItem(
      id: now.toString(),
      position: const Offset(100, 100),
      width: 240,
      height: 180,
      type: "image",
      imageBytes: bytes,
      z: now,
    );

    setState(() {
      for (var b in _boxes) b.isSelected = false;
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
        .inflate(32);
    return rect.contains(position);
  }

  void _selectBox(BoxItem box, {bool edit = false}) {
    setState(() {
      for (var b in _boxes) b.isSelected = false;
      box.isSelected = true;
      _selectedId = box.id;
      _editingBox = edit ? box : null;
      box.z = DateTime.now().millisecondsSinceEpoch; // üste al
    });
    _updateBox(box);
  }

  double _effectiveRadiusFor(BoxItem b) {
    final minSide = b.width < b.height ? b.width : b.height;
    final r = b.borderRadius;
    final asPx = (r <= 1.0) ? (r * minSide) : r;
    final maxR = minSide / 2;
    return asPx.clamp(0, maxR).toDouble();
  }

  Widget _buildTypingEditor() {
    final b = _editingTextBox!;
    final screen = MediaQuery.of(context).size;
    final kb = MediaQuery.of(context).viewInsets.bottom;

    final maxW = screen.width - 32;
    final maxH = (screen.height - kb) * .35;

    final w = b.width.clamp(24.0, maxW).toDouble();
    final h = b.height.clamp(24.0, maxH).toDouble();
    final effR = _effectiveRadiusFor(b);

    final contentW = w - 24;  // 12+12 padding
    final contentH = h - 12;  // 6+6 padding
    final fittedFs = b.autoFontSize
        ? _fitFontSizeMultiline(b, _overlayCtrl!.text, contentW, contentH)
        : b.fixedFontSize;

    // ilk frame’de odağı overlay editöre ver
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_overlayFocus.hasFocus) {
        FocusScope.of(context).requestFocus(_overlayFocus);
      }
    });

    _overlayCtrl ??= TextEditingController(text: b.text);
    // (edit başlatılırken zaten güncellemiştik, burada tekrar dokunmuyoruz)

    return Container(
      key: _overlayEditorKey,
      width: w,
      height: h,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white, // önizleme/editor: her zaman beyaz ve tam opak
        borderRadius: BorderRadius.circular(effR),
      ),
      child: TextField(
        controller: _overlayCtrl,
        focusNode: _overlayFocus,
        autofocus: true,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        maxLines: null,
        minLines: null,
        expands: true,
        textAlign: b.align,
        textAlignVertical: () {
          switch (b.vAlign) {
            case 'top':
              return TextAlignVertical.top;
            case 'bottom':
              return TextAlignVertical.bottom;
            default:
              return TextAlignVertical.center;
          }
        }(),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
        ),
        style: TextStyle(
          // multiline için auto mantığını basitleştiriyoruz:
          fontSize: fittedFs,
          fontFamily: b.fontFamily,
          fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
          decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
          color: Color(b.textColor),
        ),
        onChanged: (v) {
          b.text = v;          // canlı önizleme için canvas’ı da güncelle
          setState(() {});
        },
        onEditingComplete: _saveAndCloseEditor,
        scrollPhysics: const NeverScrollableScrollPhysics(),
      ),
    );
  }

  double _fitFontSizeMultiline(BoxItem b, String text, double maxW, double maxH,
    {double minFs = 6, double maxFs = 200}) {
    double lo = minFs, hi = maxFs;
    TextStyle styleFor(double fs) => TextStyle(
          fontSize: fs,
          fontFamily: b.fontFamily,
          fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
          decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
        );

    bool fits(double fs) {
      final tp = TextPainter(
        text: TextSpan(text: text.isEmpty ? ' ' : text, style: styleFor(fs)),
        textDirection: TextDirection.ltr,
        textAlign: b.align,
        maxLines: null,
      )..layout(maxWidth: maxW);
      return tp.size.height <= maxH + 0.5;
    }

    for (int i = 0; i < 25; i++) {
      final mid = (lo + hi) / 2;
      if (fits(mid)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  Future<void> _showTopColorPalette(BoxItem b) async {
    final topPad = MediaQuery.of(context).padding.top;
    // AppBar + status bar altı:
    final inset = EdgeInsets.only(top: topPad + kToolbarHeight + 8, left: 12, right: 12);

    await showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent, // yazma modu kapanmasın
      barrierDismissible: true,
      pageBuilder: (_, __, ___) {
        final colors = [0xFF000000,0xFF2962FF,0xFFD81B60,0xFF2E7D32,0xFFF9A825,0xFFFFFFFF];
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: inset,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8, runSpacing: 8,
                  children: colors.map((c) => GestureDetector(
                    onTap: () {
                      setState(() => b.textColor = c);
                      _updateBox(b);
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
          ),
        );
      },
    );
  }

  Widget _buildFixedTextToolbar(BoxItem b) {
    return Material(
      key: _overlayToolbarKey,
      elevation: 6,
      color: Colors.white,
      child: SizedBox(
        height: 48,
        child: SingleChildScrollView(
          controller: _toolbarScroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // boşluğa düşmesin
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.color_lens, size: 20),
                  onPressed: () => _showTopColorPalette(_editingTextBox!),
                ),
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
                  icon:
                      Icon(Icons.format_underline, size: 20, color: b.underline ? Colors.teal : null),
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
                IconButton(
                  icon: const Icon(Icons.vertical_align_top, size: 20),
                  onPressed: () {
                    setState(() => b.vAlign = 'top');
                    _updateBox(b);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.vertical_align_center, size: 20),
                  onPressed: () {
                    setState(() => b.vAlign = 'middle');
                    _updateBox(b);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.vertical_align_bottom, size: 20),
                  onPressed: () {
                    setState(() => b.vAlign = 'bottom');
                    _updateBox(b);
                  },
                ),
                const VerticalDivider(width: 12),
                // Toolbar içi (font kontrolü):
                InkWell(
                  key: _fontBtnKey,
                  onTap: () async {
                    final rb = _fontBtnKey.currentContext!.findRenderObject() as RenderBox;
                    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                    final btn = rb.localToGlobal(Offset.zero, ancestor: overlay);
                    // menü yüksekliği ~220px varsayalım, butonun biraz üstüne koy
                    final pos = RelativeRect.fromLTRB(
                      btn.dx,            // left
                      btn.dy - 220,      // top (yukarı)
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
                      // yazma modu bozulmasın
                      // (barrier yok, odak kapanmıyor; overlay yine açık kalıyor)
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
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() => b.autoFontSize = !b.autoFontSize);
                    _updateBox(b);
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
                      onChanged: (v) => setState(() => b.fixedFontSize = v),
                      onChangeEnd: (_) => _updateBox(b),
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
    // Z'ye göre yerel sıralama (En üste/alta anında çalışsın)
    final boxesSorted = [..._boxes]..sort((a, b) => a.z.compareTo(b.z));
    final kb = MediaQuery.of(context).viewInsets.bottom;

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
        // boşluğa basınca: overlay açıksa editor/toolbar dışına tıklanırsa kaydet&çık
        onTapDown: (d) {
          if (_isTypingOverlayVisible) {
            final gp = d.globalPosition;
            if (_hit(_overlayToolbarKey, gp) || _hit(_overlayEditorKey, gp)) return;
            _saveAndCloseEditor();
          }
        },
        onTap: () {
          if (_editingTextBox != null) return;
          if (_isTypingOverlayVisible) return; // overlay varsa onTapDown zaten çalıştı
          // boşluğa basınca seçimleri bırak
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
              return ResizableTextBox(
                key: ValueKey('${box.id}#$_uiEpoch'),
                box: box,
                isEditing: _editingBox == box,
                onUpdate: () => setState(() {}),
                onSave: () => _updateBox(box),
                onSelect: (edit) {
                  _selectBox(box, edit: edit);
                  if (edit && box.type == "textbox") {
                    _overlayCtrl ??= TextEditingController(text: box.text);
                    _overlayCtrl!.text = box.text;
                    _overlayCtrl!.selection = TextSelection.collapsed(
                      offset: _overlayCtrl!.text.length,
                    );
                    setState(() => _editingTextBox = box);
                  }
                },
                onDelete: () => _removeBox(box),
                isOverTrash: _isOverTrash,
                onDraggingOverTrash: (isOver) => setState(() => _draggingOverTrash = isOver),
                onInteract: (active) => setState(() => _isInteracting = active),
                onTextFocusChange: null,
                inlineToolbar: false,
                floatOnEdit: false,
                useExternalEditor: _isTypingOverlayVisible && _editingTextBox?.id == box.id,
              );
            }),

            // === Sabit Editör + Toolbar (yalnızca textbox edit + klavye açık) ===
            if (_isTypingOverlayVisible) ...[
              Positioned.fill(
                child: GestureDetector(
                  // karanlık alana dokununca kaydet & çık
                  onTap: _saveAndCloseEditor,
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
                    // paneli klavyenin üstüne getir
                    padding: EdgeInsets.only(bottom: 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Editör (önizleme değil; seçilebilir çok satır)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Center(child: _buildTypingEditor()),
                        ),
                        // Sabit yazı düzenleme paneli
                        _buildFixedTextToolbar(_editingTextBox!),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Çöp alanı (overlay editör açıkken gizle)
            if (boxesSorted.any((b) => b.isSelected) && !_isTypingOverlayVisible)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  key: _trashKey,
                  height: 100,
                  color: _draggingOverTrash
                      ? Colors.red.withAlpha((0.5 * 255).round())
                      : Colors.red.withAlpha((0.2 * 255).round()),
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
