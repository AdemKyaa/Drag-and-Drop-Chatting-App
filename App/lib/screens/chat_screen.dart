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
  BoxItem? _editingTextBox;
  final ScrollController _toolbarScroll = ScrollController();

  String getConversationId() {
    final ids = [widget.currentUserId, widget.otherUserId]..sort();
    return ids.join("_");
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
    super.dispose();
  }

  Future<void> _addBox() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final newBox = BoxItem(
      id: now.toString(),
      position: const Offset(150, 150),
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

    await messages.add({
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

    // Hemen ekranda göster
    setState(() {
      for (var b in _boxes) {
        b.isSelected = false;
      }
      newBox.isSelected = true;
      _boxes.add(newBox);
      _editingBox = null;
      _selectedId = newBox.id;
    });

    // Firestore'a yaz
    await messages.add({
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

    final snapshot = await messages
        .where("conversationId", isEqualTo: getConversationId())
        .where("id", isEqualTo: box.id)
        .get();

    for (var doc in snapshot.docs) {
      await messages.doc(doc.id).delete();
    }
  }

  Future<void> _updateBox(BoxItem box) async {
    final snapshot = await messages
        .where("conversationId", isEqualTo: getConversationId())
        .where("id", isEqualTo: box.id)
        .get();

    for (var doc in snapshot.docs) {
      await messages.doc(doc.id).update({
        ...box.toJson(
          getConversationId(),
          widget.currentUserId,
          widget.otherUserId,
        ),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    }
  }

  bool _isOverTrash(Offset position) {
    final renderBox = _trashKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return false;
    final trashPos  = renderBox.localToGlobal(Offset.zero);
    final trashSize = renderBox.size;
    final rect = Rect.fromLTWH(trashPos.dx, trashPos.dy, trashSize.width, trashSize.height)
        .inflate(32);
    return rect.contains(position);
  }

  void _selectBox(BoxItem box, {bool edit = false}) {
    setState(() {
      for (var b in _boxes) {
        b.isSelected = false;
      }
      box.isSelected = true;
      _selectedId = box.id;
      _editingBox = edit ? box : null;

      // üstte göster
      box.z = DateTime.now().millisecondsSinceEpoch;
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

  Widget _buildTypingPreview(BoxItem b) {
    final screen = MediaQuery.of(context).size;
    final kb     = MediaQuery.of(context).viewInsets.bottom;
    final maxW   = screen.width - 32;        // sağ-sol 16px marj
    final maxH   = (screen.height - kb) * .35;

    final w = b.width.clamp(24.0, maxW).toDouble();
    final h = b.height.clamp(24.0, maxH).toDouble();
    final effR = _effectiveRadiusFor(b);

    // Metin auto ise ölçek küçültmek için FittedBox kullanıyoruz (tek satır)
    final child = (b.type == "textbox")
        ? Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                b.text.isEmpty ? "Metin..." : b.text,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: b.autoFontSize ? 200 : b.fixedFontSize, // FittedBox küçültür
                  fontFamily: b.fontFamily,
                  fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
                  fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
                  decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
                  color: Color(b.textColor),
                ),
              ),
            ),
          )
        : (b.imageBytes == null || b.imageBytes!.isEmpty)
          ? const SizedBox.expand()
          : SizedBox.expand(
              child: Image.memory(
                b.imageBytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            );

    return ClipRRect(
      borderRadius: BorderRadius.circular(effR),
      child: Container(
        width: w,
        height: h,
        padding: b.type == "textbox" ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6) : EdgeInsets.zero,
        color: b.type == "image"
            ? Colors.transparent
            : Color(b.backgroundColor)
                .withAlpha((b.backgroundOpacity * 255).clamp(0, 255).toInt()),
        child: child,
      ),
    );
  }

  // ChatScreen.dart, _ChatScreenState içine EKLE (örn. _buildTypingPreview'dan sonra)
  Widget _buildFixedTextToolbar(BoxItem b) {
    return Material(
      elevation: 6,
      color: Colors.white,
      child: SizedBox(
        height: 48,
        child: SingleChildScrollView(
          controller: _toolbarScroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque, // tıklama boşluğa düşmesin
            onTap: () {},                     // gesture arena'yı sahiplen
            child: Row(
              children: [
                // Metin rengi
                IconButton(
                  icon: const Icon(Icons.color_lens, size: 20),
                  onPressed: () {
                    final colors = [
                      0xFF000000, 0xFF2962FF, 0xFFD81B60,
                      0xFF2E7D32, 0xFFF9A825, 0xFFFFFFFF
                    ];
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => SafeArea(
                        child: Padding(
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
                    );
                  },
                ),

                // Bold/Italic/Underline
                IconButton(
                  icon: Icon(Icons.format_bold, size: 20, color: b.bold ? Colors.teal : null),
                  onPressed: () { setState(() => b.bold = !b.bold); _updateBox(b); },
                ),
                IconButton(
                  icon: Icon(Icons.format_italic, size: 20, color: b.italic ? Colors.teal : null),
                  onPressed: () { setState(() => b.italic = !b.italic); _updateBox(b); },
                ),
                IconButton(
                  icon: Icon(Icons.format_underline, size: 20, color: b.underline ? Colors.teal : null),
                  onPressed: () { setState(() => b.underline = !b.underline); _updateBox(b); },
                ),

                const VerticalDivider(width: 12),

                // Yatay hizalar
                IconButton(
                  icon: const Icon(Icons.format_align_left, size: 20),
                  onPressed: () { setState(() => b.align = TextAlign.left); _updateBox(b); },
                ),
                IconButton(
                  icon: const Icon(Icons.format_align_center, size: 20),
                  onPressed: () { setState(() => b.align = TextAlign.center); _updateBox(b); },
                ),
                IconButton(
                  icon: const Icon(Icons.format_align_right, size: 20),
                  onPressed: () { setState(() => b.align = TextAlign.right); _updateBox(b); },
                ),

                const VerticalDivider(width: 12),

                // Dikey hizalar
                IconButton(
                  icon: const Icon(Icons.vertical_align_top, size: 20),
                  onPressed: () { setState(() => b.vAlign = 'top'); _updateBox(b); },
                ),
                IconButton(
                  icon: const Icon(Icons.vertical_align_center, size: 20),
                  onPressed: () { setState(() => b.vAlign = 'middle'); _updateBox(b); },
                ),
                IconButton(
                  icon: const Icon(Icons.vertical_align_bottom, size: 20),
                  onPressed: () { setState(() => b.vAlign = 'bottom'); _updateBox(b); },
                ),

                const VerticalDivider(width: 12),

                // Font ailesi
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

                // Auto / Fixed font size
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
                      min: 6, max: 200,
                      onChanged: (v) { setState(() => b.fixedFontSize = v); },
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
        onTap: () {
          if (_editingTextBox != null) return;
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
            // ⬇️ z’ye göre sıralı çizim, diğer kullanıcıya eklenenler zaten snapshots ile gelir
            ...boxesSorted.map((box) { 
              return ResizableTextBox(
                key: ValueKey(box.id),
                box: box,
                isEditing: _editingBox == box,
                onUpdate: () => setState(() {}),
                onSave: () => _updateBox(box),
                onSelect: (edit) => _selectBox(box, edit: edit),
                onDelete: () => _removeBox(box),
                isOverTrash: _isOverTrash,
                onDraggingOverTrash: (isOver) {
                  setState(() => _draggingOverTrash = isOver);
                },
                onInteract: (active) => setState(() => _isInteracting = active),
                onTextFocusChange: (hasFocus, bx) {                   // ✅ YENİ
                  setState(() {
                    _editingBox = hasFocus ? bx : null;
                    _editingTextBox = hasFocus ? bx : null;
                  });
                },
                inlineToolbar: false,   // 👈 RTB kendi toolbar’ını çizmesin
                floatOnEdit: false,     // 👈 RTB editte kendini klavyeye taşımayacak
              );
            }),

            if (boxesSorted.any((b) => b.isSelected))
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
            
            // ===== Sabit Önizleme + Toolbar (yalnızca textbox edit + klavye açık) =====
            // ===== Sabit Önizleme + Toolbar (yalnızca textbox edit + klavye açık) =====
            if (_editingTextBox != null &&
                _editingTextBox!.type == "textbox" &&
                MediaQuery.of(context).viewInsets.bottom > 0) ...[
              // 1) Karartma (overlay)
              Positioned.fill(
                child: ModalBarrier(
                  color: Colors.black.withOpacity(0.35),
                  dismissible: false,
                ),
              ),

              // 2) Klavye üstü Önizleme + Toolbar
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom - 256, // klavye üstü
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Center(child: _buildTypingPreview(_editingTextBox!)),
                        ),
                        _buildFixedTextToolbar(_editingTextBox!),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
