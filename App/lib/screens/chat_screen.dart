// lib/screens/chat_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/box_item.dart';
import '../widgets/object/text_object.dart';
import '../widgets/object/image_object.dart';
import '../widgets/delete_area.dart';

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String? otherUserId;
  final String? otherUsername;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    this.otherUserId,
    this.otherUsername,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<BoxItem> boxes = [];
  bool _editing = false;
  bool _isOverTrash = false;
  final GlobalKey _trashKey = GlobalKey();

  // 🔄 Firestore kaydetme stub’u
  Future<void> _persistBoxes() async {
    // Burada Firestore’a boxes listesini kaydedebilirsin.
    // Şimdilik boş bırakıyorum.
  }

  // ✅ Çöp alanını ölç
  bool _pointOverTrash(Offset globalPos) {
    final ctx = _trashKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null) return false;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    return globalPos.dx >= pos.dx &&
        globalPos.dx <= pos.dx + size.width &&
        globalPos.dy >= pos.dy &&
        globalPos.dy <= pos.dy + size.height;
  }

  // ✅ Drop sırasında sil
  void _handleDrop() {
    setState(() {
      boxes.removeWhere((b) => b.isSelected);
    });
    _persistBoxes();
  }

  // ✅ Textbox ekle
  void _addTextBox() {
    setState(() {
      boxes.add(BoxItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: "textbox",
        position: const Offset(100, 100),
        width: 200,
        height: 80,
        text: "",
        isSelected: true,
      ));
    });
  }

  // ✅ Resim ekle (şimdilik sahte Uint8List ile)
  void _addImageObject(Uint8List bytes) {
    setState(() {
      boxes.add(BoxItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: "image",
        position: const Offset(150, 150),
        width: 200,
        height: 200,
        imageBytes: bytes,
        isSelected: true,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUsername ?? "Chat"),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: _addTextBox,
          ),
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: () {
              // burada image_picker veya file_picker entegre edebilirsin
              // şimdilik sahte boş byte gönderiyorum:
              _addImageObject(Uint8List(0));
            },
          ),
          IconButton(
            icon: Icon(_editing ? Icons.done : Icons.edit),
            onPressed: () {
              setState(() => _editing = !_editing);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // objeler
          ...boxes.map((b) {
            if (b.type == "textbox") {
              return TextObject(
                box: b,
                isEditing: _editing,
                onUpdate: () => setState(() {}),
                onSave: _persistBoxes,
                onSelect: (edit) {
                  setState(() {
                    for (var other in boxes) {
                      other.isSelected = false;
                    }
                    b.isSelected = true;
                  });
                },
                onDelete: () {
                  setState(() => boxes.remove(b));
                  _persistBoxes();
                },
                isOverTrash: _pointOverTrash,
                onDraggingOverTrash: (v) => setState(() => _isOverTrash = v),
                onInteract: (_) {},
              );
            } else if (b.type == "image") {
              return ImageObject(
                box: b,
                isEditing: _editing,
                onUpdate: () => setState(() {}),
                onSave: _persistBoxes,
                onSelect: (edit) {
                  setState(() {
                    for (var other in boxes) {
                      other.isSelected = false;
                    }
                    b.isSelected = true;
                  });
                },
                onDelete: () {
                  setState(() => boxes.remove(b));
                  _persistBoxes();
                },
                isOverTrash: _pointOverTrash,
                onDraggingOverTrash: (v) => setState(() => _isOverTrash = v),
                onInteract: (_) {},
              );
            }
            return const SizedBox.shrink();
          }).toList(),

          // çöp alanı
          Align(
            alignment: Alignment.bottomCenter,
            child: DeleteArea(
              key: _trashKey,
              isActive: _isOverTrash,
              onOverChange: (v) => setState(() => _isOverTrash = v),
              onDrop: _handleDrop,
            ),
          ),
        ],
      ),
    );
  }
}
