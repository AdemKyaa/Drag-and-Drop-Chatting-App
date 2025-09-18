import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Blob;

class TextRangeStyle {
  final int start;
  final int end;
  final bool bold;
  final bool italic;
  final bool underline;

  TextRangeStyle({
    required this.start,
    required this.end,
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });

  Map<String, dynamic> toJson() => {
    "start": start,
    "end": end,
    "bold": bold,
    "italic": italic,
    "underline": underline,
  };

  factory TextRangeStyle.fromJson(Map<String, dynamic> json) {
    return TextRangeStyle(
      start: json["start"],
      end: json["end"],
      bold: json["bold"] ?? false,
      italic: json["italic"] ?? false,
      underline: json["underline"] ?? false,
    );
  }
}

extension BoxItemStyling on BoxItem {
  /// BoxItem.text içinden, base style'ı kullanarak (font,size,color)
  /// karakter bazlı bold/italic/underline birleşimleriyle spans üretir.
  List<TextSpan> styledSpans(TextStyle base) {
    final text = this.text;
    if (text.isEmpty) {
      return [TextSpan(text: "Metin...", style: base.copyWith(color: Colors.grey))];
    }

    final n = text.length;

    // Varsayılan (tüm metne) kutu-level stil
    final boldA = List<bool>.filled(n, bold);
    final italicA = List<bool>.filled(n, italic);
    final underA = List<bool>.filled(n, underline);

    // Aralıkları uygula (taşmaları kırp)
    for (final s in styles) {
      final start = s.start.clamp(0, n);
      final end   = s.end.clamp(0, n);
      for (int i = start; i < end; i++) {
        if (s.bold)      boldA[i]   = true;
        if (s.italic)    italicA[i] = true;
        if (s.underline) underA[i]  = true;
      }
    }

    // Aynı stil koşullarına sahip karakterleri "run"lara böl
    final spans = <TextSpan>[];
    int i = 0;
    while (i < n) {
      int j = i + 1;
      while (j < n &&
          boldA[j]   == boldA[i] &&
          italicA[j] == italicA[i] &&
          underA[j]  == underA[i]) {
        j++;
      }
      spans.add(TextSpan(
        text: text.substring(i, j),
        style: base.copyWith(
          fontWeight: boldA[i]   ? FontWeight.bold   : FontWeight.normal,
          fontStyle:  italicA[i] ? FontStyle.italic  : FontStyle.normal,
          decoration: underA[i]  ? TextDecoration.underline : TextDecoration.none,
        ),
      ));
      i = j;
    }
    return spans;
  }
}

/// Tuval üzerindeki bir nesne (textbox veya image).
class BoxItem extends ChangeNotifier {
  // Kimlik
  final String id;

  // Geometri
  Offset position;
  double width;
  double height;
  double rotation; // radians
  int z;           // z-index
  bool isSelected;

  // İçerik türü
  String type;     // "textbox" | "image"

  // Text içerik
  String text;
  List<TextRangeStyle> styles;

  // Görsel içerik (Firestore Blob / bytes)
  Uint8List? imageBytes;

  // Metin özellikleri
  double fontSize;        // legacy; auto/fixed ile birlikte bulunur
  String fontFamily;
  bool bold;
  bool italic;
  bool underline;
  TextAlign align;        // left | center | right
  bool bullet;            // kullanılmıyorsa da saklı
  String vAlign;          // 'top' | 'middle' | 'bottom'

  // Font boyutu modu
  bool autoFontSize;      // true: kutuya sığacak şekilde otomatik
  double fixedFontSize;   // auto=false iken kullanılacak boyut

  // Stil
  double borderRadius;
  int backgroundColor;      // ARGB int
  double backgroundOpacity; // 0..1
  int textColor;            // ARGB int
  double imageOpacity;      // 0..1

  BoxItem({
    required this.id,
    required this.position,
    this.width = 200,
    this.height = 100,
    this.rotation = 0,
    this.z = 0,
    this.isSelected = false,

    this.type = "textbox",
    this.text = "",
    this.imageBytes,

    this.styles = const [],
    this.fontSize = 18,
    this.fontFamily = "Roboto",
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.align = TextAlign.center,
    this.bullet = false,
    this.vAlign = 'middle',

    this.autoFontSize = true,
    this.fixedFontSize = 18.0,

    this.borderRadius = 12,
    this.backgroundColor = 0xFFFFFFFF,
    this.backgroundOpacity = 1.0,
    this.textColor = 0xFF000000,
    this.imageOpacity = 1.0,
  });

  /// Firestore’a yazım için JSON.
  Map<String, dynamic> toJson(String convId, String fromId, String toId) {
    return {
      "id": id,
      "conversationId": convId,
      "fromId": fromId,
      "toId": toId,

      "type": type,
      "text": text,
      if (imageBytes != null) "imageBytes": Blob(imageBytes!),

      "x": position.dx,
      "y": position.dy,
      "width": width,
      "height": height,
      "rotation": rotation,
      "z": z,

      // metin
      "fontSize": fontSize,
      "fontFamily": fontFamily,
      "bold": bold,
      "italic": italic,
      "underline": underline,
      "align": _alignKey(align),
      "bullet": bullet,
      "vAlign": vAlign,

      // stil
      "styles": styles.map((s) => s.toJson()).toList(),
      "borderRadius": borderRadius < 0 ? 0 : borderRadius,
      "backgroundColor": backgroundColor,      // int ARGB
      "backgroundOpacity": backgroundOpacity.clamp(0.0, 1.0),
      "textColor": textColor,                  // int ARGB
      "imageOpacity": imageOpacity.clamp(0.0, 1.0),

      // font modu
      "autoFontSize": autoFontSize,
      "fixedFontSize": fixedFontSize,
    };
  }

  static String _alignKey(TextAlign a) {
    switch (a) {
      case TextAlign.left:   return 'left';
      case TextAlign.right:  return 'right';
      case TextAlign.center: return 'center';
      default:               return 'center';
    }
  }

  /// Farklı formatlardan güvenli bytes üretir.
  static Uint8List? _bytesFrom(dynamic o) {
    if (o == null) return null;
    if (o is Uint8List) return o;
    if (o is Blob) return o.bytes;
    if (o is List) {
      try {
        return Uint8List.fromList(o.cast<int>());
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  factory BoxItem.fromJson(Map<String, dynamic> json) {
    final bgOpacity = ((json["backgroundOpacity"] as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0);
    final imgOpacity = ((json["imageOpacity"] as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0);
    final radius = ((json["borderRadius"] as num?)?.toDouble() ?? 12.0).clamp(0.0, 9999.0);

    return BoxItem(
      id: json["id"]?.toString() ?? "",
      position: Offset(
        (json["x"] ?? 0).toDouble(),
        (json["y"] ?? 0).toDouble(),
      ),
      width: ((json["width"] as num?)?.toDouble() ?? 200.0).clamp(1.0, double.infinity),
      height: ((json["height"] as num?)?.toDouble() ?? 100.0).clamp(1.0, double.infinity),
      rotation: (json["rotation"] as num?)?.toDouble() ?? 0.0,
      z: (json["z"] is num)
          ? (json["z"] as num).toInt()
          : int.tryParse(json["z"]?.toString() ?? '') ?? 0,

      type: (json["type"] ?? "textbox") as String,
      text: (json["text"] ?? "") as String,
      imageBytes: _bytesFrom(json["imageBytes"] ?? json["imageBlob"]),

      styles: (json["styles"] as List<dynamic>? ?? [])
          .map((e) => TextRangeStyle.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      fontSize: (json["fontSize"] as num?)?.toDouble() ?? 18.0,
      fontFamily: (json["fontFamily"] ?? "Roboto") as String,
      bold: (json["bold"] ?? false) as bool,
      italic: (json["italic"] ?? false) as bool,
      underline: (json["underline"] ?? false) as bool,
      align: _parseTextAlign(json["align"]),
      bullet: (json["bullet"] ?? false) as bool,
      vAlign: (json["vAlign"] as String?) ?? 'middle',

      autoFontSize: (json["autoFontSize"] as bool?) ?? true,
      fixedFontSize: (json["fixedFontSize"] as num?)?.toDouble() ?? 18.0,

      borderRadius: radius,
      backgroundColor: (json["backgroundColor"] as int?) ?? 0xFFFFFFFF,
      backgroundOpacity: bgOpacity,
      textColor: (json["textColor"] as int?) ?? 0xFF000000,
      imageOpacity: imgOpacity,
    );
  }

  static TextAlign _parseTextAlign(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'left':   return TextAlign.left;
      case 'right':  return TextAlign.right;
      case 'center': return TextAlign.center;
      default:       return TextAlign.center;
    }
  }

  void update(void Function(BoxItem b) fn) {
    fn(this);
    notifyListeners();
  }

  void toggleBold() {
    bold = !bold;
    notifyListeners();
  }

  void toggleItalic() {
    italic = !italic;
    notifyListeners();
  }

  void toggleUnderline() {
    underline = !underline;
    notifyListeners();
  }

  void setText(String newText) {
    text = newText;
    notifyListeners();
  }

  void setSelected(bool selected) {
    isSelected = selected;
    notifyListeners();
  }
}
