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
      final incoming =
          snapshot.docs.map((d) => BoxItem.fromJson(d.data())).toList();

      // z-index’e göre sırala
      incoming.sort((a, b) => a.z.compareTo(b.z));

      // Etkileşim sırasında seçili öğeyi yerelde olduğu gibi koru:
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

      // tekrar z-sırala
      merged.sort((a, b) => a.z.compareTo(b.z));

      // Seçimi koru
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

  // --- Image Picker + Firestore Blob (sıkıştırma ile) ---
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

    // başlangıç boyutu (cover kırpacağı için en/boy oranını korumak zorunda değiliz)
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
      if (_selectedId == box.id) _selectedId = null; // kritik
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
    final renderBox =
        _trashKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return false;
    final trashPos = renderBox.localToGlobal(Offset.zero);
    final trashSize = renderBox.size;

    final rect =
        Rect.fromLTWH(trashPos.dx, trashPos.dy, trashSize.width, trashSize.height)
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

      // en üste al
      _boxes.remove(box);
      _boxes.add(box);

      // kalıcı z-index
      box.z = DateTime.now().millisecondsSinceEpoch;
    });
    _updateBox(box);
  }

  void _bringToFront(BoxItem b) {
    final maxZ =
        _boxes.isEmpty ? 0 : _boxes.map((e) => e.z).reduce((a, c) => a > c ? a : c);
    b.z = maxZ + 10;
    _boxes.remove(b);
    _boxes.add(b);
    setState(() {});
    _updateBox(b);
  }

  void _sendToBack(BoxItem b) {
    final minZ =
        _boxes.isEmpty ? 0 : _boxes.map((e) => e.z).reduce((a, c) => a < c ? a : c);
    b.z = minZ - 10;
    _boxes.remove(b);
    _boxes.insert(0, b);
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
                // etkileşim başladığında stream yereli ezmesin:
                onInteract: (active) => setState(() => _isInteracting = active),
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
