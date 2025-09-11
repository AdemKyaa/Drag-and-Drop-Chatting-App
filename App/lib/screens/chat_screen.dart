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
      for (var b in _boxes) b.isSelected = false;
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
      for (var b in _boxes) b.isSelected = false;
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
        "createdAt": FieldValue.serverTimestamp(),
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
      for (var b in _boxes) b.isSelected = false;
      box.isSelected = true;
      _selectedId = box.id;
      _editingBox = edit ? box : null;

      // üstte göster
      box.z = DateTime.now().millisecondsSinceEpoch;
    });
    _updateBox(box);
  }

  @override
  Widget build(BuildContext context) {
    // Z'ye göre yerel sıralama (En üste/alta anında çalışsın)
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
        behavior: HitTestBehavior.deferToChild, // ⬅️ ESKİ: translucent
        onTap: () {
          // boşluğa basınca seçimleri bırak
          FocusScope.of(context).unfocus();
          setState(() {
            for (var b in _boxes) b.isSelected = false;
            _editingBox = null;
            _selectedId = null;
          });
        },
        child: Stack(
          children: [
            // ⬇️ z’ye göre sıralı çizim, diğer kullanıcıya eklenenler zaten snapshots ile gelir
            ...([..._boxes]..sort((a,b)=>a.z.compareTo(b.z))).map((box) {
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
