// lib/models/box_item.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';

class TextStyleSpan {
  int start;
  int end;
  bool bold;
  bool italic;
  bool underline;

  TextStyleSpan({
    required this.start,
    required this.end,
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });

  TextStyleSpan copyWith({
    int? start,
    int? end,
    bool? bold,
    bool? italic,
    bool? underline,
  }) {
    return TextStyleSpan(
      start: start ?? this.start,
      end: end ?? this.end,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
    );
  }

  Map<String, dynamic> toMap() => {
        'start': start,
        'end': end,
        'bold': bold,
        'italic': italic,
        'underline': underline,
      };

  static TextStyleSpan fromMap(Map<String, dynamic> m) => TextStyleSpan(
        start: (m['start'] ?? 0) as int,
        end: (m['end'] ?? 0) as int,
        bold: (m['bold'] ?? false) as bool,
        italic: (m['italic'] ?? false) as bool,
        underline: (m['underline'] ?? false) as bool,
      );
}

class BoxItem {
  String id;
  String type; // "textbox" | "image"
  Offset position;
  double width;
  double height;
  double rotation;
  bool isSelected;

  // text
  String text;
  double fixedFontSize;
  String fontFamily;
  bool bold;
  bool italic;
  bool underline;
  int textColor;
  double backgroundOpacity;
  int backgroundColor;
  TextAlign align;
  String vAlign;
  List<TextStyleSpan> styles;

  /// Çeviriler (ör: {"tr": "...", "en": "..."}).
  Map<String, String> translations;

  // image
  Uint8List? imageBytes; // runtime only
  double imageOpacity;
  String? imageUrl; // Storage URL

  // border
  double borderRadius;

  // z-index
  int z;

  BoxItem({
    required this.id,
    required this.type,
    this.position = const Offset(100, 100),
    this.width = 200,
    this.height = 80,
    this.rotation = 0,
    this.isSelected = false,
    this.text = "",
    this.fixedFontSize = 16,
    this.fontFamily = "Roboto",
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.textColor = 0xFF000000,
    this.backgroundOpacity = 1,
    this.backgroundColor = 0xFFFFFFFF,
    this.align = TextAlign.left,
    this.vAlign = "top",
    List<TextStyleSpan>? styles,
    this.translations = const {},
    this.imageBytes,
    this.imageOpacity = 1,
    this.imageUrl,
    this.borderRadius = 0,
    this.z = 0,
  }) : styles = styles ?? [];

  /// Görüntülenecek metni dile göre verir. Yoksa orijinal metni döndürür.
  String textFor(String lang) {
    if (lang.isEmpty) return text;
    final t = translations[lang];
    if (t != null && t.trim().isNotEmpty) return t;
    return text;
  }

  /// Çeviri yaz.
  void setTranslation(String lang, String translated) {
    final map = Map<String, String>.from(translations);
    map[lang] = translated;
    translations = map;
  }

  /// 🔹 RichText için stil uygulanmış parçalı TextSpan listesi üretir
  List<TextSpan> styledSpans(TextStyle base) {
    if (text.isEmpty) return [TextSpan(text: "Metin...", style: base.copyWith(color: Colors.grey))];

    if (styles.isEmpty) {
      return [TextSpan(text: text, style: base.copyWith(color: Color(textColor)))];
    }

    List<TextSpan> spans = [];
    int cursor = 0;

    for (var s in styles) {
      if (s.start > cursor) {
        spans.add(TextSpan(
          text: text.substring(cursor, s.start),
          style: base.copyWith(color: Color(textColor)),
        ));
      }
      spans.add(TextSpan(
        text: text.substring(s.start, s.end),
        style: base.copyWith(
          fontWeight: s.bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: s.italic ? FontStyle.italic : FontStyle.normal,
          decoration: s.underline ? TextDecoration.underline : TextDecoration.none,
          color: Color(textColor),
        ),
      ));
      cursor = s.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(
        text: text.substring(cursor),
        style: base.copyWith(color: Color(textColor)),
      ));
    }

    return spans;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'position': {'dx': position.dx, 'dy': position.dy},
        'width': width,
        'height': height,
        'rotation': rotation,
        'z': z,
        'text': text,
        'fixedFontSize': fixedFontSize,
        'fontFamily': fontFamily,
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'textColor': textColor,
        'backgroundOpacity': backgroundOpacity,
        'backgroundColor': backgroundColor,
        'align': align.index,
        'vAlign': vAlign,
        'styles': styles.map((e) => e.toMap()).toList(),
        'translations': translations,
        'imageOpacity': imageOpacity,
        'imageUrl': imageUrl, // Storage URL
        'borderRadius': borderRadius,
        'isSelected': isSelected,
      };

  static BoxItem fromMap(Map<String, dynamic> m) {
    final pos = m['position'] as Map<String, dynamic>? ?? {'dx': 100.0, 'dy': 100.0};
    final styleList = (m['styles'] as List?)?.cast<Map>() ?? const [];
    return BoxItem(
      id: (m['id'] ?? '') as String,
      type: (m['type'] ?? 'textbox') as String,
      position: Offset(
        (pos['dx'] ?? 100.0).toDouble(),
        (pos['dy'] ?? 100.0).toDouble(),
      ),
      width: (m['width'] ?? 200.0).toDouble(),
      height: (m['height'] ?? 80.0).toDouble(),
      rotation: (m['rotation'] ?? 0.0).toDouble(),
      z: (m['z'] ?? 0) as int,
      text: (m['text'] ?? '') as String,
      fixedFontSize: (m['fixedFontSize'] ?? 16.0).toDouble(),
      fontFamily: (m['fontFamily'] ?? 'Roboto') as String,
      bold: (m['bold'] ?? false) as bool,
      italic: (m['italic'] ?? false) as bool,
      underline: (m['underline'] ?? false) as bool,
      textColor: (m['textColor'] ?? 0xFF000000) as int,
      backgroundOpacity: (m['backgroundOpacity'] ?? 1.0).toDouble(),
      backgroundColor: (m['backgroundColor'] ?? 0xFFFFFFFF) as int,
      align: TextAlign.values[(m['align'] ?? TextAlign.left.index) as int],
      vAlign: (m['vAlign'] ?? 'top') as String,
      styles: styleList.map((e) => TextStyleSpan.fromMap(Map<String, dynamic>.from(e))).toList(),
      translations: Map<String, String>.from(m['translations'] ?? const {}),
      imageOpacity: (m['imageOpacity'] ?? 1.0).toDouble(),
      imageUrl: m['imageUrl'] as String?,
      borderRadius: (m['borderRadius'] ?? 0.0).toDouble(),
      isSelected: (m['isSelected'] ?? false) as bool,
    );
  }
}
