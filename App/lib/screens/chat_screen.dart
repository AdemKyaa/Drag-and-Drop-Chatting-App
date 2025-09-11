import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
  final messages = FirebaseFirestore.instance.collection("messages");

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
    messages
        .where("conversationId", isEqualTo: getConversationId())
        .snapshots()
        .listen((snapshot) {
      final newBoxes = snapshot.docs
          .map((doc) => BoxItem.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      setState(() {
        _boxes
          ..clear()
          ..addAll(newBoxes);
      });
    });
  }

  Future<void> _addBox() async {
    final newBox = BoxItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      position: const Offset(150, 150),
    );
    setState(() {
      for (var b in _boxes) b.isSelected = false;
      newBox.isSelected = true;
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

  Future<void> _addImageBox() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final storageRef = FirebaseStorage.instance
        .ref()
        .child("chat_images")
        .child("${DateTime.now().millisecondsSinceEpoch}.jpg");
    await storageRef.putFile(File(picked.path));
    final downloadUrl = await storageRef.getDownloadURL();

    final newBox = BoxItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      position: const Offset(100, 100),
      width: 200,
      height: 200,
      type: "image",
      imagePath: downloadUrl,
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
    final trashPos = renderBox.localToGlobal(Offset.zero);
    final trashSize = renderBox.size;
    final rect = Rect.fromLTWH(trashPos.dx, trashPos.dy, trashSize.width, trashSize.height);
    return rect.contains(position);
  }

  void _selectBox(BoxItem box, {bool edit = false}) {
    setState(() {
      for (var b in _boxes) b.isSelected = false;
      box.isSelected = true;
      _editingBox = edit ? box : null;

      _boxes.remove(box);
      _boxes.add(box); // en öne al
    });
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
          FocusScope.of(context).unfocus();
          setState(() {
            for (var b in _boxes) b.isSelected = false;
            _editingBox = null;
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
              );
            }),
            if (_boxes.any((b) => b.isSelected))
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  key: _trashKey,
                  height: 100,
                  color: _draggingOverTrash
                      ? Colors.red.withOpacity(0.5)
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
