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
      final incoming = snapshot.docs
        .map((d) => BoxItem.fromJson(d.data()))
        .toList();

      // Etkileşim sırasında seçili öğeyi yerelde olduğu gibi bırak:
      List<BoxItem> merged;
      if (_isInteracting && _selectedId != null) {
        final localMap = { for (final b in _boxes) b.id : b };
        merged = incoming.map((nb) {
          if (nb.id == _selectedId && localMap[_selectedId!] != null) {
            // sadece uzaktan gelen "kritik olmayan" alanları almayı da tercih edebilirsin;
            // ama en güvenlisi: tamamen yereli koru
            return localMap[_selectedId!]!;
          }
          return nb;
        }).toList();
      } else {
        merged = incoming;
      }

      merged.sort((a, b) => a.z.compareTo(b.z));
      
      // Seçimi koru (stream geldi diye kaybolmasın)
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
      z: now, // üstte başlasın
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

  // --- Image Picker + Firestore Blob (sıkıştırma ile) ---
  Future<Uint8List> _compressToFirestoreLimit(Uint8List data) async {
    final img.Image? decoded = img.decodeImage(data);
    if (decoded == null) return data;

    // 1280px’e kadar küçült
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

    // ~900KB altına çek
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

    // başlangıç boyutlarını orana göre ver
    final dec = img.decodeImage(bytes);
    double w = 220;
    double h = 220;
    if (dec != null) {
      final ratio = dec.width / dec.height;
      if (ratio >= 1) {
        w = 240;
        h = (240 / ratio);
      } else {
        h = 240;
        w = (240 * ratio);
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
      z: now, // en üstte başlat
    );

    setState(() {
      for (var b in _boxes) b.isSelected = false;
      newBox.isSelected = true;
      _selectedId = newBox.id;
      _boxes.add(newBox);
      _editingBox = null;
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

  Future<void> _removeBox(BoxItem box) async {
    setState(() {
      if (_editingBox == box) _editingBox = null;
      _boxes.remove(box);
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
        "createdAt": FieldValue.serverTimestamp(),
      });
    }
  }

  bool _isOverTrash(Offset position) {
    final renderBox = _trashKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return false;
    final trashPos  = renderBox.localToGlobal(Offset.zero);
    final trashSize = renderBox.size;

    // ✨ 24px şişir → bırakması daha kolay, kaçırma azalır
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

      // en üste al (Stack’te en sonda dursun)
      _boxes.remove(box);
      _boxes.add(box);
      // kalıcı z-index
      box.z = DateTime.now().millisecondsSinceEpoch;
    });
    _updateBox(box); // z-index’i Firestore’a yaz
  }

  void _bringToFront(BoxItem b) {
    final maxZ = _boxes.isEmpty ? 0 : _boxes.map((e) => e.z).reduce((a, c) => a > c ? a : c);
    b.z = maxZ + 10;
    _boxes.remove(b); _boxes.add(b);
    setState(() {});
    _updateBox(b);
  }

  void _sendToBack(BoxItem b) {
    final minZ = _boxes.isEmpty ? 0 : _boxes.map((e) => e.z).reduce((a, c) => a < c ? a : c);
    b.z = minZ - 10;
    _boxes.remove(b); _boxes.insert(0, b);
    setState(() {});
    _updateBox(b);
  }

  Future<void> _bringForward(BoxItem b) async {
    final sorted = [..._boxes]..sort((a, c) => a.z.compareTo(c.z));
    final i = sorted.indexOf(b);
    if (i >= 0 && i < sorted.length - 1) {
      final next = sorted[i + 1];
      final tmp = b.z;
      b.z = next.z;
      next.z = tmp;
      setState(() {});
      await _updateBox(b);
      await _updateBox(next);
    }
  }

  Future<void> _sendBackward(BoxItem b) async {
    final sorted = [..._boxes]..sort((a, c) => a.z.compareTo(c.z));
    final i = sorted.indexOf(b);
    if (i > 0) {
      final prev = sorted[i - 1];
      final tmp = b.z;
      b.z = prev.z;
      prev.z = tmp;
      setState(() {});
      await _updateBox(b);
      await _updateBox(prev);
    }
  }

  void _openEditPanel(BoxItem b) {
    // seçimi de güvence altına al
    _selectBox(b, edit: b.type == "textbox");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        // basit renk paleti
        final swatches = <Color>[
          Colors.black, Colors.white, Colors.red, Colors.green,
          Colors.blue, Colors.orange, Colors.purple, Colors.teal,
          const Color(0xFFF2F2F2), const Color(0xFF222222),
        ];

        Widget colorRow({
          required String title,
          required Color current,
          required void Function(Color c) onPick,
        }) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 12, bottom: 8),
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: swatches.map((c) {
                  final sel = c.alpha == current.alpha
                    && c.red   == current.red
                    && c.green == current.green
                    && c.blue  == current.blue;
                  return GestureDetector(
                    onTap: () {
                      onPick(c);
                      setState(() {});
                      _updateBox(b);
                    },
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sel ? Colors.teal : Colors.black12,
                          width: sel ? 2 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        }

        return Padding(
          padding: MediaQuery.of(ctx).viewInsets, // klavye vs.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                // ==== LAYER KONTROLLERİ ====
                const Text("Katman", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _bringToFront(b),
                      icon: const Icon(Icons.vertical_align_top),
                      label: const Text("En öne"),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _bringForward(b),
                      icon: const Icon(Icons.arrow_upward),
                      label: const Text("Öne"),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _sendBackward(b),
                      icon: const Icon(Icons.arrow_downward),
                      label: const Text("Arkaya"),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _sendToBack(b),
                      icon: const Icon(Icons.vertical_align_bottom),
                      label: const Text("En arkaya"),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // ==== TEXT STİLİ (sadece textbox) ====
                if (b.type == "textbox") ...[
                  const Text("Metin", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  // Hizalama
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: "Sola",
                        onPressed: () { b.align = TextAlign.left; setState(() {}); _updateBox(b); },
                        icon: Icon(Icons.format_align_left,
                          color: b.align == TextAlign.left ? Colors.teal : null),
                      ),
                      IconButton(
                        tooltip: "Ortaya",
                        onPressed: () { b.align = TextAlign.center; setState(() {}); _updateBox(b); },
                        icon: Icon(Icons.format_align_center,
                          color: b.align == TextAlign.center ? Colors.teal : null),
                      ),
                      IconButton(
                        tooltip: "Sağa",
                        onPressed: () { b.align = TextAlign.right; setState(() {}); _updateBox(b); },
                        icon: Icon(Icons.format_align_right,
                          color: b.align == TextAlign.right ? Colors.teal : null),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        tooltip: "Kalın",
                        onPressed: () { b.bold = !b.bold; setState(() {}); _updateBox(b); },
                        icon: Icon(Icons.format_bold,
                          color: b.bold ? Colors.teal : null),
                      ),
                      IconButton(
                        tooltip: "Eğik",
                        onPressed: () { b.italic = !b.italic; setState(() {}); _updateBox(b); },
                        icon: Icon(Icons.format_italic,
                          color: b.italic ? Colors.teal : null),
                      ),
                      IconButton(
                        tooltip: "Altı çizili",
                        onPressed: () { b.underline = !b.underline; setState(() {}); _updateBox(b); },
                        icon: Icon(Icons.format_underline,
                          color: b.underline ? Colors.teal : null),
                      ),
                    ],
                  ),

                  // Font ailesi
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Text("Font: "),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: b.fontFamily,
                          items: const [
                            DropdownMenuItem(value: "Roboto", child: Text("Roboto")),
                            DropdownMenuItem(value: "Arial", child: Text("Arial")),
                            DropdownMenuItem(value: "Times New Roman", child: Text("Times New Roman")),
                            DropdownMenuItem(value: "Courier New", child: Text("Courier New")),
                          ],
                          onChanged: (v) {
                            b.fontFamily = v ?? "Roboto";
                            setState(() {});
                            _updateBox(b);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Renkler
                  colorRow(
                    title: "Yazı rengi",
                    current: Color(b.textColor),        // ✅ int → Color
                    onPick: (c) { b.textColor = (c.alpha << 24) | (c.red << 16) | (c.green << 8) | c.blue; },
                  ),
                ],

                // Kutu arka planı + köşe yarıçapı (hem image hem text’te işlevsel)
                colorRow(
                  title: "Kutu arka planı",
                  current: Color(b.backgroundColor),        // ✅
                  onPick: (c) {
                    b.backgroundColor = (c.alpha << 24) | (c.red << 16) | (c.green << 8) | c.blue; // ✅
                  },
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      const Text("Köşe yuvarlaklığı"),
                      Expanded(
                        child: Slider(
                          value: b.borderRadius,
                          min: 0, max: 48,
                          onChanged: (val) { setState(() { b.borderRadius = val; }); },
                          onChangeEnd: (_) => _updateBox(b), // kaydet
                        ),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("Kapat"),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUsername),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box),
            onPressed: _addBox,
          ),
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: _addImageBox,
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          // boşluğa basınca: klavye kapat + seçimleri bırak
          FocusScope.of(context).unfocus();
          setState(() {
            for (var b in _boxes) {
              b.isSelected = false;
            }
            _editingBox = null;
            _selectedId = null;
          });
          // edit -> non-edit dönüşünü ResizableTextBox.didUpdateWidget
          // yakalayıp kaydettiğimiz için burada onSave çağırmıyoruz.
        },
        child: Stack(
          children: [
            ..._boxes.map((box) {
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
                onInteract: (active) {                    // ✨ YENİ
                  setState(() => _isInteracting = active);
                },
                onOpenPanel: (bx) => _openEditPanel(bx),
              );
            }),
            if (_boxes.any((b) => b.isSelected))
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
