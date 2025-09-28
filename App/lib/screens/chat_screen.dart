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

  final ScrollController _scrollController = ScrollController();

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
    final screenSize = MediaQuery.of(context).size;
    final scrollPos = _scrollController.offset; // o anki kaydırma
    final center = Offset(
      screenSize.width / 2,
      scrollPos + screenSize.height / 2,
    );
    final currentOffset = _scrollController.offset;

    setState(() {
      final box = BoxItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: "textbox",
        position: center - const Offset(100, 40),
        width: 200,
        height: 80,
        text: "",
        fontFamily: 'Roboto',
        isSelected: true,
      );
      boxes.add(box);
      _editingBox = box; // edit mod
    });

    // Scroll pozisyonunu geri al
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(currentOffset);
    });
  }

  Future<void> _pickImage() async {
    final screenSize = MediaQuery.of(context).size;
    final scrollPos = _scrollController.offset; // o anki kaydırma
    final center = Offset(
      screenSize.width / 2,
      scrollPos + screenSize.height / 2,
    );

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
      position: center - Offset(newWidth / 2, newHeight / 2),
      width: newWidth,
      height: newHeight,
      imageBytes: bytes,
      mimeType: mimeType,
      isSelected: true,
    );
    final currentOffset = _scrollController.offset;

    setState(() => boxes.add(box));

    // Scroll pozisyonunu geri al
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(currentOffset);
    });

    await _saveBox(box);
  }

  void _openEmojiSheet(bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ep.EmojiPicker(
          onEmojiSelected: (category, emoji) {
            Navigator.pop(context);
            _addEmoji(emoji.emoji);
          },
          config: ep.Config(
            height: 256,
            emojiViewConfig: ep.EmojiViewConfig(
              emojiSizeMax: 32,
              backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF2F2F2),
            ),
            categoryViewConfig: ep.CategoryViewConfig(
              iconColor: isDarkMode ? Colors.white70 : Colors.grey,
              iconColorSelected: Colors.blue,
              indicatorColor: Colors.blue,
              backgroundColor: isDarkMode ? Colors.black : Colors.white,
            ),
            skinToneConfig: const ep.SkinToneConfig(enabled: true),
            checkPlatformCompatibility: true,
          ),
        );
      },
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white, // ✅ panel arka planı
    );
  }

  void _addEmoji(String emoji) {
    final screenSize = MediaQuery.of(context).size;
    final scrollPos = _scrollController.offset; // o anki kaydırma
    final center = Offset(
      screenSize.width / 2,
      scrollPos + screenSize.height / 2,
    );

    final newBox = BoxItem(
      id: DateTime.now().toIso8601String(),
      type: "emoji",
      position: center - const Offset(32, 32),
      text: emoji,
      fixedFontSize: 64,
      opacity: 1.0,
      isSelected: true,
    );
    final currentOffset = _scrollController.offset;

    setState(() {
      boxes.add(newBox);
      _editingBox = newBox;
    });

    // Scroll pozisyonunu geri al
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(currentOffset);
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

      await _messagesCol.doc(b.id).set(
        {
          ...b.toMap(),
          'senderId': widget.currentUserId, // 🔹 eklenen alan
        },
        SetOptions(merge: true),
      );
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
  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId) // kendi ayarını baz alıyoruz
        .snapshots(),
    builder: (context, snap) {
      final data = snap.data?.data() ?? {};

      // 🔹 Firestore’dan tema bilgileri
      final bool isDarkMode = data['isDarkMode'] ?? false;
      final int seed = (data['themeColor'] as int?) ?? 0xFF2962FF;

      // Ana baz renk (görseldeki yeşilin temeli)
      const baseGreen = Color(0xFF2E7D32);

      // Tema renkleri
      final background = isDarkMode 
          ? const Color(0xFF1B2E24)   // koyu arkaplan
          : const Color(0xFFB9DFC1);  // pastel açık arkaplan

      final cardColor = isDarkMode 
          ? const Color(0xFF264332)   // koyu kart
          : const Color(0xFF9CC5A4);  // pastel kart

      final textColor = isDarkMode 
          ? const Color(0xFFE6F2E9)   // koyu temada açık yazı
          : const Color(0xFF1B3C2E);  // açık temada koyu yazı

      final themeColor = baseGreen;   // vurgu rengi aynı kalabilir

      final bgType = (data['chatBgType'] ?? 'color') as String;
      final bgUrl = data['chatBgUrl'] as String?;
      
      // 🔹 En alt objeyi bul → sahne yüksekliği hesapla
      final screenSize = MediaQuery.of(context).size;
      final padding = MediaQuery.of(context).padding;

      // AppBar + BottomAppBar yükseklikleri
      const bottomBarHeight = 56.0;
      final appBarHeight = kToolbarHeight + padding.top; // status bar dahil

      // Kullanılabilir alan (ekran - appbar - bottom bar - alt padding)
      final usableHeight = screenSize.height - appBarHeight - bottomBarHeight - padding.bottom - 24;

      double maxBottom = usableHeight;

      for (final b in boxes.where((x) => x.type != "delete")) {
        final bottom = b.position.dy + b.height;
        if (bottom > maxBottom) maxBottom = bottom;
      }

      // Eğer hiç obje yoksa → sadece kullanılabilir alan
      if (boxes.where((x) => x.type != "delete").isEmpty) {
        maxBottom = usableHeight;
      } else {
        // Obje varsa → objelerin altına yarım ekran ekle
        maxBottom += usableHeight * 0.5;
      }

      return Scaffold(
        appBar: AppBar(
          backgroundColor: cardColor,
          foregroundColor: textColor,
          iconTheme: IconThemeData(color: textColor),
          title: Text(
            widget.otherUsername ?? "Chat",
            style: TextStyle(color: textColor),
          ),
        ),
        backgroundColor: background,
        body: Stack(
        children: [Scrollbar(
            controller: _scrollController,
            thumbVisibility: true, // her zaman görünsün
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: _pinchTarget != null
              ? const NeverScrollableScrollPhysics() // obje seçiliyse scroll kilitli
              : const AlwaysScrollableScrollPhysics(), // değilse normal
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: maxBottom,
                  minWidth: screenSize.width,
                ),
                child: Listener(
              onPointerDown: (event) {
                if (_pinchTarget != null && _pinchPrimaryId != event.pointer) {
                  // ikinci parmak
                  _pinchSecondaryId = event.pointer;
                  _pinchSecondaryStartGlobal = event.position;
                  _pinchStartDistance =
                      (_pinchPrimaryStartGlobal! - _pinchSecondaryStartGlobal!).distance;
                  _pinchStartAngle = atan2(
                    _pinchSecondaryStartGlobal!.dy - _pinchPrimaryStartGlobal!.dy,
                    _pinchSecondaryStartGlobal!.dx - _pinchPrimaryStartGlobal!.dx,
                  );
                }
              },
              onPointerMove: (event) {
                if (_pinchTarget != null &&
                    _pinchPrimaryStartGlobal != null &&
                    event.pointer == _pinchSecondaryId) {
                  final newDist =
                      (_pinchPrimaryStartGlobal! - event.position).distance;
                  final scale = newDist / _pinchStartDistance;

                  setState(() {
                    if (_pinchTarget!.type == "emoji") {
                      // ✅ Emoji büyüyüp küçülsün
                      _pinchTarget!.fixedFontSize = _pinchStartFont * scale;
                    } else if (_pinchTarget!.type == "image") {
                      // ✅ Image genişlik/yükseklik büyüsün
                      _pinchTarget!.width = _pinchStartW * scale;
                      _pinchTarget!.height = _pinchStartH * scale;
                    }
                    // ✅ Textbox sadece açı değişsin
                    _pinchTarget!.rotation =
                        _pinchStartRot +
                        atan2(
                          event.position.dy - _pinchPrimaryStartGlobal!.dy,
                          event.position.dx - _pinchPrimaryStartGlobal!.dx,
                        ) -
                        _pinchStartAngle;
                  });
                }
              },
              onPointerUp: (event) {
                if (event.pointer == _pinchPrimaryId ||
                    event.pointer == _pinchSecondaryId) {
                  if (_pinchTarget != null) {
                    _saveBox(_pinchTarget!); // ✅ değişiklikleri Firestore’a kaydet
                  }
                  _pinchTarget = null;
                  _pinchPrimaryId = null;
                  _pinchSecondaryId = null;
                }
              },
              child: Stack(
                key: _stageKey,
                children: [
                  // 1) Arkaplan
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
                        : const DecoratedBox(
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage("assets/splash/seamless_bg.png"),
                                repeat: ImageRepeat.repeat, // ✅ desen tekrarlansın
                              ),
                            ),
                          ),
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
                      final minX = b.width / 2;
                      final maxX = screenSize.width - b.width / 2;
                      final safeX = b.position.dx.clamp(minX, maxX);
                      return Positioned(
                        left: safeX,
                        top: b.position.dy,
                        child:TextObject(
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
                          currentUserId: widget.currentUserId,
                          isOverTrash: _pointOverTrash,
                          onDraggingOverTrash: (v) =>
                              setState(() => _isOverTrash = v),
                          onInteract: (_) {},
                          onPrimaryPointerDown: (box, pid, globalPos) {
                            _beginPinchFromObject(box, pid, globalPos);
                          },
                          onBringToFront: () {
                            setState(() {
                              final maxZ = boxes.isEmpty
                                  ? 0
                                  : boxes
                                      .map((e) => e.z)
                                      .reduce((a, c) => a > c ? a : c);
                              b.z = maxZ + 1;
                              boxes.sort((a, c) => a.z.compareTo(c.z));
                            });
                            _saveBox(b);
                          },
                          onSendToBack: () {
                            setState(() {
                              final minZ = boxes.isEmpty
                                  ? 0
                                  : boxes
                                      .map((e) => e.z)
                                      .reduce((a, c) => a < c ? a : c);
                              b.z = minZ - 1;
                              boxes.sort((a, c) => a.z.compareTo(c.z));
                            });
                            _saveBox(b);
                          },
                          isDarkMode: isDarkMode,
                        )
                      );
                    } else if (b.type == "image") {
                      final minX = b.width / 2;
                      final maxX = screenSize.width - b.width / 2;
                      final safeX = b.position.dx.clamp(minX, maxX);
                      return Positioned(
                        left: safeX,
                        top: b.position.dy,
                        child: ImageObject(
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
                          currentUserId: widget.currentUserId,
                          isOverTrash: _pointOverTrash,
                          onDraggingOverTrash: (v) =>
                              setState(() => _isOverTrash = v),
                          onInteract: (_) {},
                          onPrimaryPointerDown: (box, pid, globalPos) {
                            _beginPinchFromObject(box, pid, globalPos);
                          },
                          onBringToFront: () {
                            setState(() {
                              final maxZ = boxes.isEmpty
                                  ? 0
                                  : boxes
                                      .map((e) => e.z)
                                      .reduce((a, c) => a > c ? a : c);
                              b.z = maxZ + 1;
                              boxes.sort((a, c) => a.z.compareTo(c.z));
                            });
                            _saveBox(b);
                          },
                          onSendToBack: () {
                            setState(() {
                              final minZ = boxes.isEmpty
                                  ? 0
                                  : boxes
                                      .map((e) => e.z)
                                      .reduce((a, c) => a < c ? a : c);
                              b.z = minZ - 1;
                              boxes.sort((a, c) => a.z.compareTo(c.z));
                            });
                            _saveBox(b);
                          },
                          isDarkMode: isDarkMode,
                        )
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
                        onInteract: (_) {},
                        isOverTrash: _pointOverTrash,
                        onDraggingOverTrash: (v) =>
                            setState(() => _isOverTrash = v),
                        onPrimaryPointerDown: (box, pid, globalPos) {
                          _beginPinchFromObject(box, pid, globalPos);
                        },
                        currentUserId: widget.currentUserId,
                        onBringToFront: () {
                          setState(() {
                            final maxZ = boxes.isEmpty
                                ? 0
                                : boxes
                                    .map((e) => e.z)
                                    .reduce((a, c) => a > c ? a : c);
                            b.z = maxZ + 1;
                            boxes.sort((a, c) => a.z.compareTo(c.z));
                          });
                          _saveBox(b);
                        },
                        onSendToBack: () {
                          setState(() {
                            final minZ = boxes.isEmpty
                                ? 0
                                : boxes
                                    .map((e) => e.z)
                                    .reduce((a, c) => a < c ? a : c);
                            b.z = minZ - 1;
                            boxes.sort((a, c) => a.z.compareTo(c.z));
                          });
                          _saveBox(b);
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  }).toList(),

                  // 4) Çöp alanı
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: DeleteArea(
                      key: _trashKey,
                      isActive: _isOverTrash,
                      onOverChange: (v) => setState(() => _isOverTrash = v),
                      onDrop: _handleDrop,
                    ),
                  ),

                  // 5) Paneller
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
                                : boxes
                                    .map((e) => e.z)
                                    .reduce((a, c) => a > c ? a : c);
                            _editingBox!.z = maxZ + 1;
                            boxes.sort((a, c) => a.z.compareTo(c.z));
                          });
                          _saveBox(_editingBox!);
                        },
                        onSendToBack: () {
                          setState(() {
                            final minZ = boxes.isEmpty
                                ? 0
                                : boxes
                                    .map((e) => e.z)
                                    .reduce((a, c) => a < c ? a : c);
                            _editingBox!.z = minZ - 1;
                            boxes.sort((a, c) => a.z.compareTo(c.z));
                          });
                          _saveBox(_editingBox!);
                        },
                        currentUserId: widget.currentUserId,
                      ),
                    ),
                ],
              )
            )
          ))
        ),Positioned(
        left: (screenSize.width / 2 - 30),
        top: usableHeight - 80,
        child: DeleteArea(
          key: _trashKey,
          isActive: _isOverTrash,
          onOverChange: (v) => setState(() => _isOverTrash = v),
          onDrop: _handleDrop,
        ),
      ),
      ]),

        bottomNavigationBar: BottomAppBar(
          color: cardColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                  icon: Icon(Icons.text_fields, color: textColor),
                  onPressed: _addTextBox),
              IconButton(
                icon: Icon(Icons.emoji_emotions, color: textColor),
                onPressed: () => _openEmojiSheet(isDarkMode),
              ),
              IconButton(
                  icon: Icon(Icons.image, color: textColor),
                  onPressed: _pickImage),
            ],
          ),
        ),
      );
    },
  );
}

}
