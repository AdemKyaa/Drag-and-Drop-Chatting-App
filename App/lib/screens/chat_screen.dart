// lib/screens/chat_screen.dart
// ignore_for_file: unnecessary_type_check

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

    // ÇÖZÜM: Resmin orijinal boyutlarını al ve oranını koru
    var decodedImage = await decodeImageFromList(bytes);
    double originalWidth = decodedImage.width.toDouble();
    double originalHeight = decodedImage.height.toDouble();
    double aspectRatio = originalWidth / originalHeight;

    const double maxSize = 250.0; // Ekranda ilk oluşacağı maksimum boyut
    double newWidth;
    double newHeight;

    if (aspectRatio > 1) { // Geniş resim
      newWidth = maxSize;
      newHeight = maxSize / aspectRatio;
    } else { // Yüksek veya kare resim
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
      isSelected: true,
    );

    setState(() => boxes.add(box));

    await _saveBox(box);
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
          debugPrint("Resim yükleniyor...");
          final ref = _storage.ref().child('${_chatId()}/${b.id}.jpg');
          await ref.putData(
            b.imageBytes!,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          b.imageUrl = null;
          b.imageBytes = null; // Yüklendikten sonra byte'ları temizle
          debugPrint("Resim yüklendi, URL: ${b.imageUrl}");
        }
      }

      await _messagesCol.doc(b.id).set(b.toMap(), SetOptions(merge: true));
      debugPrint("${b.id} ID'li nesne kaydedildi.");
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      debugPrint("HATA! _saveBox başarısız: $e");
      // Kullanıcıya bir hata mesajı göstermek için
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
        key: _stageKey,
        children: [
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

        // objeler
        ...boxes.map((b) {
          if (b.type == "textbox") {
            return TextObject(
              box: b,
              displayLang: _targetLang,
              isEditing: _editingBox == b,
              onUpdate: () => setState(() {}),
              onSave: () async {
                await _saveBox(b);
              },
              onSelect: (edit) {
                setState(() {
                  for (final other in boxes) {
                    other.isSelected = false; // diğerlerini bırak
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
              onPrimaryPointerDown: (box, pid, globalPos) {
                _beginPinchFromObject(box, pid, globalPos);
              },
              onBringToFront: () {
                setState(() {
                  final values = boxes.map((e) => (e.z is num) ? (e.z as num).toDouble() : 0.0);
                  final maxZ = values.isEmpty ? 0.0 : values.reduce((a, c) => a > c ? a : c);
                  b.z = (maxZ + 1).toInt();
                  boxes.sort((a, b) => a.z.compareTo(b.z));
                });
                _saveBox(b);
              },
              onSendToBack: () {
                setState(() {
                  final values = boxes.map((e) => (e.z is num) ? (e.z as num).toDouble() : 0.0);
                  final minZ = values.isEmpty ? 0.0 : values.reduce((a, c) => a < c ? a : c);
                  b.z = (minZ - 1).toInt();
                  boxes.sort((a, b) => a.z.compareTo(b.z));
                });
                _saveBox(b);
              },
            );
          } else if (b.type == "image") {
            return ImageObject(
              box: b,
              isEditing: false,
              onUpdate: () => setState(() {}),
              onSave: () async {
                await _saveBox(b);
              },
              onSelect: (edit) {
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
                  final values = boxes.map((e) => (e.z is num) ? (e.z as num).toDouble() : 0.0);
                  final maxZ = values.isEmpty ? 0.0 : values.reduce((a, c) => a > c ? a : c);
                  b.z = (maxZ + 1).toInt();
                  boxes.sort((a, b) => a.z.compareTo(b.z));
                });
                _saveBox(b);
              },
              onSendToBack: () {
                setState(() {
                  final values = boxes.map((e) => (e.z is num) ? (e.z as num).toDouble() : 0.0);
                  final minZ = values.isEmpty ? 0.0 : values.reduce((a, c) => a < c ? a : c);
                  b.z = (minZ - 1).toInt();
                  boxes.sort((a, b) => a.z.compareTo(b.z));
                });
                _saveBox(b);
              },
            );
          }
            return const SizedBox.shrink();
          }),

          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) {
                // Eğer bir obje üzerinde “bir parmak” zaten basılı ise ve ikinci parmak yoksa:
                if (_pinchTarget != null && _pinchPrimaryId != null && _pinchSecondaryId == null) {
                  // İkinci parmak bu obje DIŞINA mı geldi?
                  if (!_pointInsideRotatedBox(_pinchTarget!, e.position)) {
                    _pinchSecondaryId = e.pointer;
                    _pinchSecondaryStartGlobal = e.position;

                    // iki parmak arasındaki ilk vektör (primary -> secondary)
                    final p1 = _pinchPrimaryStartGlobal!;
                    final p2 = _pinchSecondaryStartGlobal!;
                    final v = p2 - p1;
                    _pinchStartDistance = v.distance;
                    _pinchStartAngle = v.direction; // atan2

                    _overlayPinchActive = true;
                  }
                }
              },
              onPointerMove: (e) {
                // Sadece overlay pinch modunda işliyoruz (ikinci parmak obje dışında)
                if (_overlayPinchActive && _pinchTarget != null && _pinchPrimaryId != null && _pinchSecondaryId != null) {
                  // Primary veya secondary hareket ettiyse güncelle
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
                    measureText(b, 2000);
                    final lineCount = _lineCount(b);

                    const padH = 32.0, padV = 24.0;

                    b.fixedFontSize = (_pinchStartFont * scale).clamp(8.0, 300.0);

                    final scaledTextSize = measureText(b, 2000);

                    b.width = (scaledTextSize.width + padH).clamp(24.0, 4096.0);
                    b.height = (lineCount * b.fixedFontSize * 1.2 + padV).clamp(24.0, 4096.0);
                    b.rotation = _pinchStartRot + deltaAng;
                  } else if (b.type == 'image') {
                    b.width  = (_pinchStartW * scale).clamp(32.0, 4096.0);
                    b.height = (_pinchStartH * scale).clamp(32.0, 4096.0);
                    b.rotation = _pinchStartRot + deltaAng;
                  }

                  setState(() {}); // anlık yansıt
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
                  if (b != null) {
                    _saveBox(b); // Firestore’a yaz
                  }
                  // tüm pinchi bitir
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