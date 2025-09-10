import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final users = FirebaseFirestore.instance.collection("users");

  final List<BoxItem> _boxes = [];
  BoxItem? _editingBox;
  final GlobalKey _trashKey = GlobalKey();
  bool _draggingOverTrash = false;

  String getConversationId() {
    final ids = [widget.currentUserId, widget.otherUserId]..sort();
    return ids.join("_");
  }

  Future<void> _addBox() async {
    final newBox = BoxItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      position: const Offset(100, 100),
    );

    await messages.add({
      ...newBox.toJson(
        getConversationId(),
        widget.currentUserId,
        widget.otherUserId,
      ),
      "createdAt": FieldValue.serverTimestamp(), // ✅ Firestore timestamp
    });
  }

  void _selectBox(BoxItem box, {bool edit = false}) {
    setState(() {
      for (var b in _boxes) {
        b.isSelected = false;
      }
      box.isSelected = true;
      _editingBox = edit ? box : null;
    });
  }

  void _clearSelection() {
    setState(() {
      for (var b in _boxes) {
        b.isSelected = false;
      }
      _editingBox = null;
    });
  }

  void _removeBox(BoxItem box) async {
    final snapshot = await messages
        .where("conversationId", isEqualTo: getConversationId())
        .where("id", isEqualTo: box.id)
        .get();

    for (var doc in snapshot.docs) {
      await messages.doc(doc.id).delete();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUsername),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box),
            onPressed: _addBox,
          )
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusScope.of(context).unfocus();
          _clearSelection();
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: messages
              .where("conversationId", isEqualTo: getConversationId())
              .orderBy("createdAt", descending: true) // ✅ index ile uyumlu
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text("❌ Hata: ${snapshot.error}"));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("Henüz kutu yok"));
            }

            final docs = snapshot.data!.docs;
            _boxes.clear();
            for (var doc in docs) {
              _boxes.add(BoxItem.fromJson(doc.data() as Map<String, dynamic>));
            }

            return Stack(
              children: [
                ..._boxes.map((box) {
                  return ResizableTextBox(
                    key: ValueKey(box.id),
                    box: box,
                    isEditing: _editingBox == box,
                    onUpdate: () async {
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
                      setState(() {});
                    },
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
            );
          },
        ),
      ),
    );
  }
}
