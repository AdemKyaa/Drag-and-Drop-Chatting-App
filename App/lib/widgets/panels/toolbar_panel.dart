// lib/widgets/panels/toolbar_panel.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/box_item.dart';

class ToolbarPanel extends StatefulWidget {
  final BoxItem box;
  final VoidCallback onUpdate; // anlık UI refresh
  final VoidCallback onSave;   // kalıcı kaydet
  final VoidCallback onClose;  // paneli kapat

  const ToolbarPanel({
    super.key,
    required this.box,
    required this.onUpdate,
    required this.onSave,
    required this.onClose,
  });

  @override
  State<ToolbarPanel> createState() => _ToolbarPanelState();
}

class _ToolbarPanelState extends State<ToolbarPanel> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  static const List<String> _fonts = <String>[
    'Roboto',
    'Open Sans',
    'Lato',
    'Montserrat',
    'Poppins',
    'Raleway',
    'Merriweather',
    'Ubuntu',
  ];

  // ==== Stil işlemleri ====

  void _toggleInline({
    required String field, // "bold" | "italic" | "underline"
    required int start,
    required int end,
  }) {
    final b = widget.box;
    if (start >= end) return;

    bool fullOn = _isFieldFullyOn(b.styles, field, start, end);
    _cutFieldInRange(b.styles, field, start, end);

    if (!fullOn) {
      b.styles.add(TextStyleSpan(
        start: start,
        end: end,
        bold: field == "bold",
        italic: field == "italic",
        underline: field == "underline",
      ));
      _mergeOverlaps(b.styles);
    }
  }

  bool _isFieldFullyOn(List<TextStyleSpan> styles, String field, int a, int b) {
    int covered = 0;
    for (final s in styles) {
      final int sa = s.start;
      final int sb = s.end;
      final bool on = (field == 'bold' && s.bold) ||
          (field == 'italic' && s.italic) ||
          (field == 'underline' && s.underline);
      if (!on) continue;
      final int ia = (sa > a) ? sa : a;
      final int ib = (sb < b) ? sb : b;
      if (ib > ia) covered += (ib - ia);
      if (covered >= (b - a)) return true;
    }
    return false;
  }

  void _cutFieldInRange(List<TextStyleSpan> styles, String field, int a, int b) {
    final out = <TextStyleSpan>[];
    for (final s in styles) {
      final int sa = s.start;
      final int sb = s.end;

      final bool on = (field == 'bold' && s.bold) ||
          (field == 'italic' && s.italic) ||
          (field == 'underline' && s.underline);

      if (!on) {
        out.add(s);
        continue;
      }

      if (sb <= a || sa >= b) {
        out.add(s);
        continue;
      }

      if (sa < a) {
        out.add(s.copyWith(end: a));
      }
      if (sb > b) {
        out.add(s.copyWith(start: b));
      }
    }
    styles
      ..clear()
      ..addAll(out);
  }

  void _mergeOverlaps(List<TextStyleSpan> styles) {
    if (styles.isEmpty) return;
    styles.sort((x, y) => x.start.compareTo(y.start));

    final merged = <TextStyleSpan>[];
    var cur = styles.first;

    for (int i = 1; i < styles.length; i++) {
      final nxt = styles[i];
      if (_canMerge(cur, nxt)) {
        cur = cur.copyWith(end: nxt.end);
      } else {
        merged.add(cur);
        cur = nxt;
      }
    }
    merged.add(cur);

    styles
      ..clear()
      ..addAll(merged);
  }

  bool _sameFlags(TextStyleSpan a, TextStyleSpan b) =>
      (a.bold == b.bold) && (a.italic == b.italic) && (a.underline == b.underline);

  bool _canMerge(TextStyleSpan a, TextStyleSpan b) =>
      _sameFlags(a, b) && (a.end >= b.start);

  // ==== Lifecycle ====

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.box.text);
    _controller.addListener(() {
      widget.box.text = _controller.text;
      widget.onUpdate();
    });
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ==== UI ====

  @override
  Widget build(BuildContext context) {
    final b = widget.box;

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                widget.onSave();
                widget.onClose();
              },
              child: Container(color: Colors.black54),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 📋 Önizleme
                Container(
                  width: b.width,
                  constraints: const BoxConstraints(minHeight: 60, maxHeight: 260),
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  color: Color(b.backgroundColor).withAlpha(255),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    maxLines: null,
                    expands: false,
                    textAlign: b.align,
                    style: GoogleFonts.getFont(
                      b.fontFamily.isEmpty ? "Roboto" : b.fontFamily,
                      textStyle: TextStyle(
                        fontSize: b.fixedFontSize,
                        fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
                        fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
                        decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
                        color: Color(b.textColor),
                      ),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: 'Metin...',
                    ),
                  ),
                ),

                // ✍️ Toolbar
                Container(
                  width: double.infinity,
                  color: Colors.grey[900],
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // 🔹 Hizalama butonları
                        IconButton(
                          tooltip: "Sola hizala",
                          icon: const Icon(Icons.format_align_left, color: Colors.white),
                          onPressed: () {
                            setState(() => b.align = TextAlign.left);
                            widget.onUpdate();
                          },
                        ),
                        IconButton(
                          tooltip: "Ortala",
                          icon: const Icon(Icons.format_align_center, color: Colors.white),
                          onPressed: () {
                            setState(() => b.align = TextAlign.center);
                            widget.onUpdate();
                          },
                        ),
                        IconButton(
                          tooltip: "Sağa hizala",
                          icon: const Icon(Icons.format_align_right, color: Colors.white),
                          onPressed: () {
                            setState(() => b.align = TextAlign.right);
                            widget.onUpdate();
                          },
                        ),

                        const SizedBox(width: 8),

                        // 🔹 Bold
                        IconButton(
                          tooltip: "Kalın",
                          icon: Icon(Icons.format_bold,
                              color: b.bold ? Colors.amber : Colors.white),
                          onPressed: () {
                            final sel = _controller.selection;
                            if (sel.isValid && !sel.isCollapsed) {
                              _toggleInline(field: "bold", start: sel.start, end: sel.end);
                            } else {
                              b.bold = !b.bold;
                            }
                            widget.onUpdate();
                          },
                        ),

                        // 🔹 Italic
                        IconButton(
                          tooltip: "İtalik",
                          icon: Icon(Icons.format_italic,
                              color: b.italic ? Colors.amber : Colors.white),
                          onPressed: () {
                            final sel = _controller.selection;
                            if (sel.isValid && !sel.isCollapsed) {
                              _toggleInline(field: "italic", start: sel.start, end: sel.end);
                            } else {
                              b.italic = !b.italic;
                            }
                            widget.onUpdate();
                          },
                        ),

                        // 🔹 Underline
                        IconButton(
                          tooltip: "Altı çizili",
                          icon: Icon(Icons.format_underline,
                              color: b.underline ? Colors.amber : Colors.white),
                          onPressed: () {
                            final sel = _controller.selection;
                            if (sel.isValid && !sel.isCollapsed) {
                              _toggleInline(field: "underline", start: sel.start, end: sel.end);
                            } else {
                              b.underline = !b.underline;
                            }
                            widget.onUpdate();
                          },
                        ),

                        const SizedBox(width: 8),

                        // 🔹 Font seçici
                        IconButton(
                          tooltip: "Yazı tipi",
                          icon: const Icon(Icons.font_download, color: Colors.white),
                          onPressed: () async {
                            final selected = await showModalBottomSheet<String>(
                              context: context,
                              builder: (ctx) => ListView(
                                children: _fonts
                                    .map(
                                      (f) => ListTile(
                                        title: Text(f, style: GoogleFonts.getFont(f)),
                                        onTap: () => Navigator.pop(ctx, f),
                                      ),
                                    )
                                    .toList(),
                              ),
                            );
                            if (selected != null) {
                              setState(() => b.fontFamily = selected);
                              widget.onUpdate();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
