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
        _editingTextBox!.type == "textbox" &&
        kb > 0;
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

  void _saveAndCloseEditor() {
    final b = _editingTextBox;
    final c = _overlayCtrl;
    if (b == null || c == null) return;
    b.text = c.text;
    _updateBox(b);
    FocusScope.of(context).unfocus();
    setState(() {
      _editingTextBox = null;
    });
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
    });
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
    });
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
    await messages.doc(box.id).update({
      ...box.toJson(
        getConversationId(),
        widget.currentUserId,
        widget.otherUserId,
      ),
      "updatedAt": FieldValue.serverTimestamp(),
    });
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
          fontSize: b.autoFontSize ? b.fixedFontSize : b.fixedFontSize,
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
      ),
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
                  onPressed: () {
                    final colors = [
                      0xFF000000, 0xFF2962FF, 0xFFD81B60,
                      0xFF2E7D32, 0xFFF9A825, 0xFFFFFFFF
                    ];
                    showModalBottomSheet(
                      context: context,
                      barrierColor: Colors.transparent, // kararma yok
                      builder: (_) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: colors
                                .map((c) => GestureDetector(
                                      onTap: () {
                                        setState(() => b.textColor = c);
                                        _updateBox(b);
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
                DropdownButton<String>(
                  value: b.fontFamily,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: "Roboto", child: Text("Roboto")),
                    DropdownMenuItem(value: "Arial", child: Text("Arial")),
                    DropdownMenuItem(value: "Times New Roman", child: Text("Times New Roman")),
                    DropdownMenuItem(value: "Courier New", child: Text("Courier New")),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => b.fontFamily = v);
                    _updateBox(b);
                  },
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
                key: ValueKey(box.id),
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
              // NOT: Karartma YOK (istenmedi)
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
