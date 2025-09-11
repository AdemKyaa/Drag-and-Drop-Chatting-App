import 'package:flutter/material.dart';

class BoxItem {
  final String id;
  Offset position;
  double width;
  double height;
  bool isSelected;
  String text;
  String? imagePath;
  String type; // "textbox" veya "image"
  double rotation;

  // text özellikleri
  double fontSize;
  String fontFamily;
  bool bold;
  bool italic;
  bool underline;
  TextAlign align;
  bool bullet;

  BoxItem({
    required this.id,
    required this.position,
    this.width = 200,
    this.height = 100,
    this.isSelected = false,
    this.text = "",
    this.imagePath,
    this.type = "textbox",
    this.rotation = 0,
    this.fontSize = 18,
    this.fontFamily = "Roboto",
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.align = TextAlign.center,
    this.bullet = false,
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
      "text": text,
      "imagePath": imagePath,
      "fontSize": fontSize,
      "fontFamily": fontFamily,
      "bold": bold,
      "italic": italic,
      "underline": underline,
      "align": align.toString(),
      "bullet": bullet,
    };
  }

  factory BoxItem.fromJson(Map<String, dynamic> json) {
    return BoxItem(
      id: json["id"] ?? "",
      position: Offset(
        (json["x"] ?? 0).toDouble(),
        (json["y"] ?? 0).toDouble(),
      ),
      width: (json["width"] ?? 200).toDouble(),
      height: (json["height"] ?? 100).toDouble(),
      rotation: (json["rotation"] ?? 0).toDouble(),
      text: json["text"] ?? "",
      imagePath: json["imagePath"],
      type: json["type"] ?? "textbox",
      fontSize: (json["fontSize"] ?? 18).toDouble(),
      fontFamily: json["fontFamily"] ?? "Roboto",
      bold: json["bold"] ?? false,
      italic: json["italic"] ?? false,
      underline: json["underline"] ?? false,
      align: _parseTextAlign(json["align"]),
      bullet: json["bullet"] ?? false,
    );
  }

  static TextAlign _parseTextAlign(String? value) {
    if (value == null) return TextAlign.center;
    if (value.contains("left")) return TextAlign.left;
    if (value.contains("right")) return TextAlign.right;
    return TextAlign.center;
  }
}
