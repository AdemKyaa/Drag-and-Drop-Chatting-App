// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/box_item.dart';
import '../widgets/object/text_object.dart';
import '../widgets/object/image_object.dart';
import '../widgets/delete_area.dart';
import '../widgets/panels/toolbar_panel.dart';
import '../widgets/panels/image_edit_panel.dart';
import '../services/translate_service.dart';

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

  // şu an düzenlenen kutu (Toolbar açık olan)
  BoxItem? _editingBox;

  // Dil (UI ve görüntüleme dili)
  String _targetLang = 'tr'; // varsayılan TR

  // Firestore/Storage referansları
  late final FirebaseFirestore _db;
  late final FirebaseStorage _storage;

  // LibreTranslate
  final _translator = TranslateService(
    baseUrl: 'https://libretranslate.com', // kendi endpoint’iniz varsa değiştirin
    apiKey: null,
  );

  late final CollectionReference _messagesCol;

  @override
  void initState() {
    super.initState();
    _db = FirebaseFirestore.instance;
    _storage = FirebaseStorage.instance;

    final chatId = _chatId();
    _messagesCol = _db.collection('chats').doc(chatId).collection('messages');

    _listenMessages(); // realtime dinleme
  }

  void _listenMessages() {
    _messagesCol.orderBy('z').snapshots().listen((snap) {
      final list = <BoxItem>[];
      for (final d in snap.docs) {
        list.add(BoxItem.fromMap(d.data() as Map<String, dynamic>));
      }
      setState(() {
        boxes
          ..clear()
          ..addAll(list);
      });
    });
  }

  String _chatId() {
    final a = widget.currentUserId;
    final b = widget.otherUserId ?? 'solo';
    return (a.compareTo(b) < 0) ? '$a-$b' : '$b-$a';
  }

  // ==== Çöp Alanı ====
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

  void _handleDrop() {
    setState(() {
      boxes.removeWhere((b) => b.isSelected);
    });
    _persistBoxes();
  }

  // ==== Ekleme ====
  void _addTextBox() {
    setState(() {
      final box = BoxItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: "textbox",
        position: const Offset(100, 100),
        width: 200,
        height: 80,
        text: "",
        fontFamily: 'Roboto',
        isSelected: true,
      );
      boxes.add(box);
      _editingBox = box; // edit mod
    });
  }

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
      _persistBoxes(); // Storage’a yükle & Firestore’a yaz
    }
  }

  // ==== Çeviri ====
  Future<void> _translateAndSaveFor(BoxItem b) async {
    if (b.type != 'textbox') return;
    final srcText = b.text.trim();
    if (srcText.isEmpty) return;

    final translated = await _translator.translate(
      text: srcText,
      source: 'auto',
      target: _targetLang,
    );
    b.setTranslation(_targetLang, translated);
    await _saveBox(b);
    setState(() {}); // yansıt
  }

  // ==== Firestore/Storage ====
  Future<void> _persistBoxes() async {
    for (final b in boxes) {
      await _saveBox(b);
    }
  }

  Future<void> _saveBox(BoxItem b) async {
    if (b.type == 'image' && b.imageBytes != null && (b.imageUrl == null || b.imageUrl!.isEmpty)) {
      final ref = _storage.ref().child('chats/${_chatId()}/images/${b.id}.bin');
      await ref.putData(b.imageBytes!);
      b.imageUrl = await ref.getDownloadURL();
    }
    await _messagesCol.doc(b.id).set(b.toMap(), SetOptions(merge: true));
  }


  // Dil değiştiğinde görünümü güncelle & çeviri cache’lenmemişse üret
  Future<void> _setLang(String lang) async {
    setState(() => _targetLang = lang);
    // Eksik çevirileri üret
    for (final b in boxes) {
      if (b.type == 'textbox') {
        final exists = (b.translations[lang]?.trim().isNotEmpty ?? false);
        if (!exists && b.text.trim().isNotEmpty) {
          // lazımsa çevir
          final t = await _translator.translate(text: b.text, source: 'auto', target: lang);
          b.setTranslation(lang, t);
          await _saveBox(b);
        }
      }
    }
    setState(() {});
  }

  // ==== UI ====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUsername ?? "Chat"),
        actions: [
          // Dil seçimi
          PopupMenuButton<String>(
            icon: const Icon(Icons.translate),
            onSelected: (v) => _setLang(v),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'tr', child: Text('Türkçe')),
              PopupMenuItem(value: 'en', child: Text('English')),
            ],
          ),
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
                displayLang: _targetLang, // <<< seçilen dile göre göster
                isEditing: _editingBox == b,
                onUpdate: () => setState(() {}),
                onSave: () async {
                  setState(() => _editingBox = null);
                  await _translateAndSaveFor(b); // kaydederken seçili dile çevir
                },
                onSelect: (edit) {
                  setState(() {
                    for (final other in boxes) {
                      other.isSelected = false;
                    }
                    b.isSelected = true;

                    if (edit) {
                      _editingBox = b;
                    } else {
                      _editingBox = null;
                    }
                  });
                },
                onDelete: () async {
                  setState(() {
                    boxes.remove(b);
                    if (_editingBox == b) _editingBox = null;
                  });
                  await _messagesCol.doc(b.id).delete();
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
                  onDelete: () async {
                    setState(() => boxes.remove(b));
                    await _messagesCol.doc(b.id).delete();
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

          // Toolbar panel (TextObject içinden zaten açılıyor/kapaniyor olabilir; varsa koruyun)
          if (_editingBox != null && _editingBox!.type == "textbox")
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ToolbarPanel(
                box: _editingBox!,
                onUpdate: () => setState(() {}),
                onSave: () async {
                  final b = _editingBox!;
                  setState(() => _editingBox = null);
                  await _translateAndSaveFor(b);
                },
                onClose: () => setState(() => _editingBox = null),
              ),
            ),
        ],
      ),
    );
  }
}
