import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Blob;

class BoxItem {
  final String id;
  Offset position;
  double width;
  double height;
  bool isSelected;

  // içerik
  String type; // "textbox" | "image"
  String text;
  Uint8List? imageBytes; // Firestore Blob/bytes

  // görünüm
  double rotation;

  // z-öncelik (üstte görünmesi için)
  int z;

  // metin özellikleri
  double fontSize;
  String fontFamily;
  bool bold;
  bool italic;
  bool underline;
  TextAlign align;
  bool bullet;

  // 🎨 stil
  double borderRadius;
  int backgroundColor;          // ARGB int
  double backgroundOpacity;     // 0..1
  int textColor;                // ARGB int
  double imageOpacity;          // 0..1

  String vAlign;                // 'top' | 'middle' | 'bottom'
  bool autoFontSize;            // true: otomatik sığdır
  double fixedFontSize;         // auto=false iken kullanılacak boyut

  BoxItem({
    required this.id,
    required this.position,
    this.width = 200,
    this.height = 100,
    this.isSelected = false,
    this.type = "textbox",
    this.text = "",
    this.imageBytes,
    this.rotation = 0,
    this.z = 0,
    this.fontSize = 18,
    this.fontFamily = "Roboto",
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.align = TextAlign.center,
    this.bullet = false,
    this.borderRadius = 12,
    this.backgroundColor = 0xFFFFFFFF,
    this.backgroundOpacity = 1.0,
    this.textColor = 0xFF000000,
    this.imageOpacity = 1.0,
    this.vAlign = 'middle',
    this.autoFontSize = true,
    this.fixedFontSize = 18.0,
  });

  Map<String, dynamic> toJson(String convId, String fromId, String toId) {
    return {
      "id": id,
      "conversationId": convId,
      "fromId": fromId,
      "toId": toId,
      "type": type,
      "x": position.dx,
      "y": position.dy,
      "width": width,
      "height": height,
      "rotation": rotation,
      "z": z,
      "text": text,
      if (imageBytes != null) "imageBytes": Blob(imageBytes!), // 👈 Blob olarak yaz
      "fontSize": fontSize,
      "fontFamily": fontFamily,
      "bold": bold,
      "italic": italic,
      "underline": underline,
      "align": align.toString(),
      "bullet": bullet,
      "borderRadius": borderRadius,
      "backgroundColor": backgroundColor,
      "backgroundOpacity": backgroundOpacity,
      "textColor": textColor,
      "imageOpacity": imageOpacity,
      "vAlign": vAlign,
      "autoFontSize": autoFontSize,
      "fixedFontSize": fixedFontSize,
    };
  }

  /// Farklı formatlardan (Blob, Uint8List, List<int>) güvenli bytes üretir.
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
      id: json["id"] ?? "",
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
      text: json["text"] ?? "",
      imageBytes: _bytesFrom(json["imageBytes"] ?? json["imageBlob"]),
      fontSize: (json["fontSize"] as num?)?.toDouble() ?? 18.0,
      fontFamily: json["fontFamily"] ?? "Roboto",
      bold: json["bold"] ?? false,
      italic: json["italic"] ?? false,
      underline: json["underline"] ?? false,
      align: _parseTextAlign(json["align"]?.toString()),
      bullet: json["bullet"] ?? false,
      borderRadius: (json["borderRadius"] as num?)?.toDouble() ?? 12.0,
      backgroundColor: (json["backgroundColor"] as int?) ?? 0xFFFFFFFF,
      backgroundOpacity: (json["backgroundOpacity"] as num?)?.toDouble() ?? 1.0,
      textColor: (json["textColor"] as int?) ?? 0xFF000000,
      imageOpacity: (json["imageOpacity"] as num?)?.toDouble() ?? 1.0,
      vAlign: (json["vAlign"] as String?) ?? 'middle',
      autoFontSize: (json["autoFontSize"] as bool?) ?? true,
      fixedFontSize: (json["fixedFontSize"] as num?)?.toDouble()
        ?? (json["fontSize"] as num?)?.toDouble()
        ?? 18.0,
    );
  }

  static TextAlign _parseTextAlign(String? value) {
    if (value == null) return TextAlign.center;
    final v = value.toLowerCase();
    if (v.contains("left")) return TextAlign.left;
    if (v.contains("right")) return TextAlign.right;
    if (v.contains("center")) return TextAlign.center;
    return TextAlign.center;
  }
}
