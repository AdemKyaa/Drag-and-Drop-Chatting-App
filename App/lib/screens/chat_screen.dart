// lib/screens/chat_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/box_item.dart';
import '../widgets/object/text_object.dart';
import '../widgets/object/image_object.dart';
import '../widgets/delete_area.dart';
import '../widgets/panels/toolbar_panel.dart';
import '../widgets/panels/image_edit_panel.dart';

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
  bool _isOverTrash = false;
  final GlobalKey _trashKey = GlobalKey();

  BoxItem? _editingBox; // şu an düzenlenen kutu

  // 🔄 Firestore kaydetme stub’u
  Future<void> _persistBoxes() async {
    // Burada Firestore’a boxes listesini kaydedebilirsin.
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
    final box = BoxItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: "textbox",
      position: const Offset(100, 100),
      width: 200,
      height: 80,
      text: "",
      fontFamily: "Roboto", // 🔥 Arial yerine Roboto
      isSelected: true,
    );
      boxes.add(box);
      _editingBox = box; // eklenir eklenmez düzenleme moduna geç
    });
  }

  // ✅ Resim ekle (galeriden)
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
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
            onPressed: _pickImage,
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
                isEditing: _editingBox == b, // sadece seçilen kutu editlenir
                onUpdate: () => setState(() {}),
                onSave: () {
                  setState(() => _editingBox = null);
                  _persistBoxes();
                },
                onSelect: (edit) {
                  setState(() {
                    for (var other in boxes) {
                      other.isSelected = false;
                    }
                    b.isSelected = true;
                    if (edit) {
                      _editingBox = b;
                    }
                  });
                },
                onDelete: () {
                  setState(() {
                    boxes.remove(b);
                    if (_editingBox == b) _editingBox = null;
                  });
                  _persistBoxes();
                },
                isOverTrash: _pointOverTrash,
                onDraggingOverTrash: (v) => setState(() => _isOverTrash = v),
                onInteract: (v) {},
              );
            } else if (b.type == "image") {
              return GestureDetector(
                onDoubleTap: () async {
                  await showModalBottomSheet(
                    context: context,
                    builder: (_) => ImageEditPanel(
                      box: b,
                      onUpdate: () => setState(() {}),
                      onSave: _persistBoxes,
                    ),
                  );
                },
                child: ImageObject(
                  box: b,
                  isEditing: false,
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
                ),
              );
            }
            return const SizedBox.shrink();
          }),

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

          // ==== Düzenleme Modu (textbox için) ====
          if (_editingBox != null && _editingBox!.type == "textbox")
            ToolbarPanel(
              box: _editingBox!,
              onUpdate: () => setState(() {}),
              onSave: _persistBoxes,
              onClose: () {
                setState(() => _editingBox = null);
              },
            ),
        ],
      ),
    );
  }
}
