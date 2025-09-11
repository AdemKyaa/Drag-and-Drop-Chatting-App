import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Blob;

/// Tuval üzerindeki bir nesne (textbox veya image).
class BoxItem {
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
      "align": align.toString(), // "TextAlign.center" vb.
      "bullet": bullet,
      "vAlign": vAlign,

      // stil
      "borderRadius": borderRadius,
      "backgroundColor": backgroundColor,      // int ARGB
      "backgroundOpacity": backgroundOpacity,  // 0..1
      "textColor": textColor,                  // int ARGB
      "imageOpacity": imageOpacity,            // 0..1

      // font modu
      "autoFontSize": autoFontSize,
      "fixedFontSize": fixedFontSize,
    };
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
    return BoxItem(
      id: json["id"]?.toString() ?? "",
      position: Offset(
        (json["x"] ?? 0).toDouble(),
        (json["y"] ?? 0).toDouble(),
      ),
      width: (json["width"] as num?)?.toDouble() ?? 200.0,
      height: (json["height"] as num?)?.toDouble() ?? 100.0,
      rotation: (json["rotation"] as num?)?.toDouble() ?? 0.0,
      z: (json["z"] is num)
          ? (json["z"] as num).toInt()
          : int.tryParse(json["z"]?.toString() ?? '') ?? 0,

      type: (json["type"] ?? "textbox") as String,
      text: (json["text"] ?? "") as String,
      imageBytes: _bytesFrom(json["imageBytes"] ?? json["imageBlob"]),

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

      borderRadius: (json["borderRadius"] as num?)?.toDouble() ?? 12.0,
      backgroundColor: (json["backgroundColor"] as int?) ?? 0xFFFFFFFF,
      backgroundOpacity: (json["backgroundOpacity"] as num?)?.toDouble() ?? 1.0,
      textColor: (json["textColor"] as int?) ?? 0xFF000000,
      imageOpacity: (json["imageOpacity"] as num?)?.toDouble() ?? 1.0,
    );
  }

  static TextAlign _parseTextAlign(dynamic value) {
    if (value == null) return TextAlign.center;
    final s = value.toString().toLowerCase();
    if (s.contains('left')) return TextAlign.left;
    if (s.contains('right')) return TextAlign.right;
    if (s.contains('center')) return TextAlign.center;
    return TextAlign.center;
  }
}
