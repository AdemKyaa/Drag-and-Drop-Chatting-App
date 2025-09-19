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

  // image
  Uint8List? imageBytes;
  double imageOpacity;

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
    this.fontFamily = "Arial",
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.textColor = 0xFF000000,
    this.backgroundOpacity = 1,
    this.backgroundColor = 0xFFFFFFFF,
    this.align = TextAlign.left,
    this.vAlign = "top",
    this.styles = const [],
    this.imageBytes,
    this.imageOpacity = 1,
    this.borderRadius = 0,
    this.z = 0,
  });

  // 🔹 RichText için styledSpans
  List<TextSpan> styledSpans(TextStyle base) {
    if (text.isEmpty) {
      return [
        TextSpan(text: "Metin...", style: base.copyWith(color: Colors.grey)),
      ];
    }

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
}
