import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/box_item.dart';
import '../widgets/object/text_object.dart';
import '../widgets/object/image_object.dart';
import '../widgets/delete_area.dart';
import '../widgets/panels/toolbar_panel.dart';
import '../widgets/panels/emoji_edit_panel.dart';
import '../widgets/object/resizable_emoji_box.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as ep;

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
  // Object Scaling
  final GlobalKey _stageKey = GlobalKey(); // sahnenin global pozisyonunu hesaplamak için

  // Global pinch/rotate state
  BoxItem? _pinchTarget;
  int? _pinchPrimaryId;
  Offset? _pinchPrimaryStartGlobal;

  int? _pinchSecondaryId;
  Offset? _pinchSecondaryStartGlobal;

  double _pinchStartW = 0;
  double _pinchStartH = 0;
  double _pinchStartRot = 0;
  double _pinchStartFont = 0;

  double _pinchStartDistance = 0; // iki parmak arası mesafe
  double _pinchStartAngle = 0; // atan2 açısı
  bool _overlayPinchActive = false;

  Offset _stageTopLeftGlobal() {
    final ro = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    if (ro == null) return Offset.zero;
    return ro.localToGlobal(Offset.zero);
  }

  void _beginPinchFromObject(BoxItem b, int pointerId, Offset globalPos) {
    // Zaten başka obje ile pinch varsa yok say
    if (_pinchTarget != null && _pinchTarget != b) return;

    _pinchTarget = b;
    _pinchPrimaryId = pointerId;
    _pinchPrimaryStartGlobal = globalPos;

    _pinchSecondaryId = null;
    _pinchSecondaryStartGlobal = null;
    _overlayPinchActive = false;

    _pinchStartW = b.width;
    _pinchStartH = b.height;
    _pinchStartRot = b.rotation;
    _pinchStartFont = b.fixedFontSize;

    _pinchStartDistance = 0;
    _pinchStartAngle = 0;
  }

  bool _pointInsideRotatedBox(BoxItem b, Offset globalPos) {
    final stageOrigin = _stageTopLeftGlobal();
    final center = stageOrigin + b.position + Offset(b.width / 2, b.height / 2);

    final dx = globalPos.dx - center.dx;
    final dy = globalPos.dy - center.dy;

    final angle = -b.rotation; // ters dönüş
    final rotatedX = dx * cos(angle) - dy * sin(angle);
    final rotatedY = dx * sin(angle) + dy * cos(angle);

    return rotatedX.abs() <= b.width / 2 && rotatedY.abs() <= b.height / 2;
  }

  // şu an düzenlenen kutu (Toolbar açık olan)
  BoxItem? _editingBox;

  // Dil (UI ve görüntüleme dili)
  String _targetLang = 'tr'; // varsayılan TR

  // Firestore/Storage referansları
  late final FirebaseFirestore _db;
  late final FirebaseStorage _storage;

  late final CollectionReference _messagesCol;

  @override
  void initState() {
    super.initState();
    _db = FirebaseFirestore.instance;
    _storage = FirebaseStorage.instance;

    final chatId = _chatId();
    _messagesCol = _db.collection(chatId);

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
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final mimeType = picked.mimeType ?? 'image/jpeg';

    // ÇÖZÜM: Resmin orijinal boyutlarını al ve oranını koru
    var decodedImage = await decodeImageFromList(bytes);
    double originalWidth = decodedImage.width.toDouble();
    double originalHeight = decodedImage.height.toDouble();
    double aspectRatio = originalWidth / originalHeight;

    const double maxSize = 250.0; // Ekranda ilk oluşacağı maksimum boyut
    double newWidth;
    double newHeight;

    if (aspectRatio > 1) {
      // Geniş resim
      newWidth = maxSize;
      newHeight = maxSize / aspectRatio;
    } else {
      // Yüksek veya kare resim
      newHeight = maxSize;
      newWidth = maxSize * aspectRatio;
    }

    final box = BoxItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: "image",
      position: const Offset(150, 150),
      width: newWidth,
      height: newHeight,
      imageBytes: bytes,
      mimeType: mimeType,
      isSelected: true,
    );

    setState(() => boxes.add(box));

    await _saveBox(box);
  }

  void _openEmojiSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ep.EmojiPicker(
          onEmojiSelected: (category, emoji) {
            Navigator.pop(context);
            _addEmoji(emoji.emoji);
          },
          config: const ep.Config(
            height: 256,
            emojiViewConfig: ep.EmojiViewConfig(
              emojiSizeMax: 32,
              backgroundColor: Color(0xFFF2F2F2),
            ),
            categoryViewConfig: ep.CategoryViewConfig(
              iconColor: Colors.grey,
              iconColorSelected: Colors.blue,
              indicatorColor: Colors.blue,
            ),
            skinToneConfig: ep.SkinToneConfig(enabled: true),
            checkPlatformCompatibility: true,
          ),
        );
      },
    );
  }

  void _addEmoji(String emoji) {
    final newBox = BoxItem(
      id: DateTime.now().toIso8601String(),
      type: "emoji",
      position: const Offset(120, 120),
      text: emoji,
      fixedFontSize: 64,
      opacity: 1.0,
      isSelected: true,
    );

    setState(() {
      boxes.add(newBox);
      _editingBox = newBox;
    });

    _saveBox(newBox);
  }

  // ==== Çeviri ====
  Future<void> _translateAndSaveFor(BoxItem b) async {
    if (b.type != 'textbox') return;
    final srcText = b.text.trim();
    if (srcText.isEmpty) return;

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
    try {
      if (b.type == 'image') {
        if ((b.imageUrl == null || b.imageUrl!.isEmpty) && b.imageBytes != null) {
          final mimeType = b.mimeType ?? 'image/jpeg';

          String ext = 'jpg';
          if (mimeType.contains('png')) {
            ext = 'png';
          } else if (mimeType.contains('gif')) {
            ext = 'gif';
          } else if (mimeType.contains('webp')) {
            ext = 'webp';
          }

          final ref = _storage.ref().child('${_chatId()}/${b.id}.$ext');

          await ref.putData(
            b.imageBytes!,
            SettableMetadata(contentType: mimeType),
          );

          b.imageUrl = await ref.getDownloadURL();
          b.imageBytes = null;

          debugPrint("✅ Resim yüklendi, URL: ${b.imageUrl}");
        }
      }

      if (b.imageUrl == null && b.type == 'image') {
        debugPrint("⚠️ Uyarı: imageUrl boş kaldı! Bu object-not-found sebebi olabilir.");
      }

      await _messagesCol.doc(b.id).set(b.toMap(), SetOptions(merge: true));
      debugPrint("📥 ${b.id} Firestore’a kaydedildi.");
    } catch (e) {
      debugPrint("❌ HATA! _saveBox başarısız: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kaydetme hatası: $e")),
      );
    }
  }

  Future<void> _setLang(String lang) async {
    setState(() => _targetLang = lang);
    // Eksik çevirileri üret
    for (final b in boxes) {
      if (b.type == 'textbox') {
        final exists = (b.translations[lang]?.trim().isNotEmpty ?? false);
        if (!exists && b.text.trim().isNotEmpty) {
          await _saveBox(b);
        }
      }
    }
    setState(() {});
  }

  int _lineCount(BoxItem b, {double maxWidth = 2000}) {
    final style = GoogleFonts.getFont(
      b.fontFamily.isEmpty ? 'Roboto' : b.fontFamily,
      textStyle: TextStyle(fontSize: b.fixedFontSize),
    );

    final span = TextSpan(style: style, children: b.styledSpans(style));

    final tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    return tp.computeLineMetrics().length;
  }

  Size measureText(BoxItem b, double maxWidth) {
    final baseStyle = GoogleFonts.getFont(
      b.fontFamily.isEmpty ? 'Roboto' : b.fontFamily,
      textStyle: TextStyle(
        fontSize: b.fixedFontSize,
        fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
        fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
        decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
        color: Color(b.textColor),
      ),
    );

    final tp = TextPainter(
      text: TextSpan(text: b.text, style: baseStyle),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    return Size(tp.width, tp.height);
  }

  // ==== UI ====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUsername ?? "Chat"),
        actions: [
          // Dil seçimi menüsü
          PopupMenuButton<String>(
            icon: const Icon(Icons.translate),
            onSelected: (v) => _setLang(v),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'tr', child: Text('Türkçe')),
              PopupMenuItem(value: 'en', child: Text('English')),
            ],
          ),

          // Text ekleme
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: _addTextBox,
          ),

          // Resim ekleme
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: _pickImage,
          ),

          // Emoji ekleme
          IconButton(
            icon: const Icon(Icons.emoji_emotions),
            onPressed: _openEmojiSheet,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.currentUserId) // kendi ayarını baz alıyoruz
            .snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() ?? {};
          final bgType = (data['chatBgType'] ?? 'color') as String;
          final bgColorInt = (data['chatBgColor'] ?? 0xFFFFFFFF) as int;
          final bgColor = Color(bgColorInt);
          final bgUrl = data['chatBgUrl'] as String?;

          return Stack(
            key: _stageKey,
            children: [
              // 1) Arkaplan (en altta)
              Positioned.fill(
                child: bgType == 'image' && (bgUrl?.isNotEmpty ?? false)
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(bgUrl!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    : Container(color: bgColor),
              ),

              // 2) Boş alana basınca seçimleri kaldır
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    setState(() {
                      for (final b in boxes) {
                        b.isSelected = false;
                      }
                      _editingBox = null;
                    });
                  },
                ),
              ),

              // 3) Objeler (textbox / image / emoji)
              ...boxes.map((b) {
                if (b.type == "textbox") {
                  return TextObject(
                    box: b,
                    displayLang: _targetLang,
                    isEditing: _editingBox == b,
                    onUpdate: () => setState(() {}),
                    onSave: () async => _saveBox(b),
                    onSelect: (edit) {
                      setState(() {
                        for (final other in boxes) {
                          other.isSelected = false;
                        }
                        b.isSelected = true;
                        _editingBox = edit ? b : null;
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
                    onInteract: (_) {},
                    onPrimaryPointerDown: (box, pid, globalPos) {
                      _beginPinchFromObject(box, pid, globalPos);
                    },
                    onBringToFront: () {
                      setState(() {
                        final maxZ = boxes.isEmpty
                            ? 0
                            : boxes.map((e) => e.z).reduce((a, c) => a > c ? a : c);
                        b.z = maxZ + 1;
                        boxes.sort((a, c) => a.z.compareTo(c.z));
                      });
                      _saveBox(b);
                    },
                    onSendToBack: () {
                      setState(() {
                        final minZ = boxes.isEmpty
                            ? 0
                            : boxes.map((e) => e.z).reduce((a, c) => a < c ? a : c);
                        b.z = minZ - 1;
                        boxes.sort((a, c) => a.z.compareTo(c.z));
                      });
                      _saveBox(b);
                    },
                  );
                } else if (b.type == "image") {
                  return ImageObject(
                    box: b,
                    isEditing: false,
                    onUpdate: () => setState(() {}),
                    onSave: () async => _saveBox(b),
                    onSelect: (_) {
                      setState(() {
                        for (final other in boxes) {
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
                    onPrimaryPointerDown: (box, pid, globalPos) {
                      _beginPinchFromObject(box, pid, globalPos);
                    },
                    onBringToFront: () {
                      setState(() {
                        final maxZ = boxes.isEmpty
                            ? 0
                            : boxes.map((e) => e.z).reduce((a, c) => a > c ? a : c);
                        b.z = maxZ + 1;
                        boxes.sort((a, c) => a.z.compareTo(c.z));
                      });
                      _saveBox(b);
                    },
                    onSendToBack: () {
                      setState(() {
                        final minZ = boxes.isEmpty
                            ? 0
                            : boxes.map((e) => e.z).reduce((a, c) => a < c ? a : c);
                        b.z = minZ - 1;
                        boxes.sort((a, c) => a.z.compareTo(c.z));
                      });
                      _saveBox(b);
                    },
                  );
                } else if (b.type == "emoji") {
                  return ResizableEmojiBox(
                    box: b,
                    isEditing: _editingBox == b,
                    onUpdate: () => setState(() {}),
                    onSave: () async => _saveBox(b),
                    onSelect: (edit) {
                      setState(() {
                        for (final other in boxes) {
                          other.isSelected = false;
                        }
                        b.isSelected = true;
                        _editingBox = edit ? b : null;
                      });
                    },
                    onDelete: () async {
                      setState(() => boxes.remove(b));
                      await _messagesCol.doc(b.id).delete();
                    },
                    isOverTrash: _pointOverTrash,
                    onDraggingOverTrash: (v) => setState(() => _isOverTrash = v),
                    onPrimaryPointerDown: (box, pid, globalPos) {
                      _beginPinchFromObject(box, pid, globalPos);
                    },
                    onBringToFront: () {
                      setState(() {
                        final maxZ = boxes.isEmpty
                            ? 0
                            : boxes.map((e) => e.z).reduce((a, c) => a > c ? a : c);
                        b.z = maxZ + 1;
                        boxes.sort((a, c) => a.z.compareTo(c.z));
                      });
                      _saveBox(b);
                    },
                    onSendToBack: () {
                      setState(() {
                        final minZ = boxes.isEmpty
                            ? 0
                            : boxes.map((e) => e.z).reduce((a, c) => a < c ? a : c);
                        b.z = minZ - 1;
                        boxes.sort((a, c) => a.z.compareTo(c.z));
                      });
                      _saveBox(b);
                    },
                  );
                }
                return const SizedBox.shrink();
              }).toList(),

              // 4) İki parmakla global pinch/rotate dinleyicisi
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (e) {
                    if (_pinchTarget != null &&
                        _pinchPrimaryId != null &&
                        _pinchSecondaryId == null) {
                      if (!_pointInsideRotatedBox(_pinchTarget!, e.position)) {
                        _pinchSecondaryId = e.pointer;
                        _pinchSecondaryStartGlobal = e.position;
                        final p1 = _pinchPrimaryStartGlobal!;
                        final p2 = _pinchSecondaryStartGlobal!;
                        final v = p2 - p1;
                        _pinchStartDistance = v.distance;
                        _pinchStartAngle = v.direction;
                        _overlayPinchActive = true;
                      }
                    }
                  },
                  onPointerMove: (e) {
                    if (_overlayPinchActive &&
                        _pinchTarget != null &&
                        _pinchPrimaryId != null &&
                        _pinchSecondaryId != null) {
                      if (e.pointer == _pinchPrimaryId) {
                        _pinchPrimaryStartGlobal = e.position;
                      } else if (e.pointer == _pinchSecondaryId) {
                        _pinchSecondaryStartGlobal = e.position;
                      }
                      final p1 = _pinchPrimaryStartGlobal!;
                      final p2 = _pinchSecondaryStartGlobal!;
                      final v = p2 - p1;
                      final dist = v.distance.clamp(0.001, 1e6);
                      final ang = v.direction;

                      final scale = (dist / (_pinchStartDistance == 0 ? dist : _pinchStartDistance)).clamp(0.1, 100.0);
                      final deltaAng = ang - _pinchStartAngle;

                      final b = _pinchTarget!;
                      if (b.type == 'textbox') {
                        final lineCount = _lineCount(b);
                        const padH = 32.0, padV = 24.0;
                        b.fixedFontSize = (_pinchStartFont * scale).clamp(8.0, 300.0);
                        final scaledTextSize = measureText(b, 2000);
                        b.width = (scaledTextSize.width + padH).clamp(24.0, 4096.0);
                        b.height = (lineCount * b.fixedFontSize * 1.2 + padV).clamp(24.0, 4096.0);
                        b.rotation = _pinchStartRot + deltaAng;
                      } else if (b.type == 'image') {
                        b.width = (_pinchStartW * scale).clamp(32.0, 4096.0);
                        b.height = (_pinchStartH * scale).clamp(32.0, 4096.0);
                        b.rotation = _pinchStartRot + deltaAng;
                      } else if (b.type == 'emoji') {
                        b.fixedFontSize = (_pinchStartFont * scale).clamp(16.0, 300.0);
                        b.rotation = _pinchStartRot + deltaAng;
                      }
                      setState(() {});
                    }
                  },
                  onPointerUp: (e) {
                    if (e.pointer == _pinchSecondaryId) {
                      _pinchSecondaryId = null;
                      _pinchSecondaryStartGlobal = null;
                      _overlayPinchActive = false;
                    }
                    if (e.pointer == _pinchPrimaryId) {
                      final b = _pinchTarget;
                      if (b != null) _saveBox(b);
                      _pinchTarget = null;
                      _pinchPrimaryId = null;
                      _pinchPrimaryStartGlobal = null;
                      _pinchSecondaryId = null;
                      _pinchSecondaryStartGlobal = null;
                      _overlayPinchActive = false;
                    }
                  },
                  onPointerCancel: (e) {
                    if (e.pointer == _pinchSecondaryId) {
                      _pinchSecondaryId = null;
                      _pinchSecondaryStartGlobal = null;
                      _overlayPinchActive = false;
                    }
                    if (e.pointer == _pinchPrimaryId) {
                      _pinchTarget = null;
                      _pinchPrimaryId = null;
                      _pinchPrimaryStartGlobal = null;
                      _pinchSecondaryId = null;
                      _pinchSecondaryStartGlobal = null;
                      _overlayPinchActive = false;
                    }
                  },
                ),
              ),

              // 5) Çöp alanı
              Align(
                alignment: Alignment.bottomCenter,
                child: DeleteArea(
                  key: _trashKey,
                  isActive: _isOverTrash,
                  onOverChange: (v) => setState(() => _isOverTrash = v),
                  onDrop: _handleDrop,
                ),
              ),

              // 6) Paneller
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
                )
              else if (_editingBox != null && _editingBox!.type == "emoji")
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: EmojiEditPanel(
                    box: _editingBox!,
                    onUpdate: () => setState(() {}),
                    onSave: () async {
                      final b = _editingBox!;
                      setState(() => _editingBox = null);
                      await _saveBox(b);
                    },
                    onClose: () => setState(() => _editingBox = null),
                    onBringToFront: () {
                      setState(() {
                        final maxZ = boxes.isEmpty
                            ? 0
                            : boxes.map((e) => e.z).reduce((a, c) => a > c ? a : c);
                        _editingBox!.z = maxZ + 1;
                        boxes.sort((a, c) => a.z.compareTo(c.z));
                      });
                      _saveBox(_editingBox!);
                    },
                    onSendToBack: () {
                      setState(() {
                        final minZ = boxes.isEmpty
                            ? 0
                            : boxes.map((e) => e.z).reduce((a, c) => a < c ? a : c);
                        _editingBox!.z = minZ - 1;
                        boxes.sort((a, c) => a.z.compareTo(c.z));
                      });
                      _saveBox(_editingBox!);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
