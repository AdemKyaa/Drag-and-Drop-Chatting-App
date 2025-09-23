import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/box_item.dart';

class ToolbarPanel extends StatefulWidget {
  final BoxItem box;
  final VoidCallback onUpdate; // anlık
  final VoidCallback onSave;   // kalıcı
  final VoidCallback onClose;  // panel kapat

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
    'Roboto','Open Sans','Lato','Montserrat','Poppins','Raleway','Merriweather','Ubuntu',
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.box.text);
    _controller.addListener(() {
      // ANLIK: orijinal textbox metni güncellensin
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

  // --- inline stil yardımcıları ---

  void _toggleInline({
    required String field, // "bold" | "italic" | "underline"
    required int start,
    required int end,
  }) {
    final b = widget.box;
    if (start >= end) return;

    final fullOn = _isFieldFullyOn(b.styles, field, start, end);
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
    widget.onUpdate();
  }

  bool _isFieldFullyOn(List<TextStyleSpan> styles, String field, int a, int b) {
    int covered = 0;
    for (final s in styles) {
      final sa = s.start, sb = s.end;
      final on = (field == 'bold' && s.bold) ||
                 (field == 'italic' && s.italic) ||
                 (field == 'underline' && s.underline);
      if (!on) continue;
      final ia = (sa > a) ? sa : a;
      final ib = (sb < b) ? sb : b;
      if (ib > ia) covered += (ib - ia);
      if (covered >= (b - a)) return true;
    }
    return false;
  }

  void _cutFieldInRange(List<TextStyleSpan> styles, String field, int a, int b) {
    final out = <TextStyleSpan>[];
    for (final s in styles) {
      final sa = s.start, sb = s.end;
      final on = (field == 'bold' && s.bold) ||
                 (field == 'italic' && s.italic) ||
                 (field == 'underline' && s.underline);

      if (!on) { out.add(s); continue; }
      if (sb <= a || sa >= b) { out.add(s); continue; }

      if (sa < a) out.add(s.copyWith(end: a));
      if (sb > b) out.add(s.copyWith(start: b));
      // [a,b) düşer → kapatılmış olur
    }
    styles..clear()..addAll(out);
  }

  void _mergeOverlaps(List<TextStyleSpan> styles) {
    if (styles.isEmpty) return;
    styles.sort((x, y) => x.start.compareTo(y.start));
    final merged = <TextStyleSpan>[];
    var cur = styles.first;
    for (int i = 1; i < styles.length; i++) {
      final nxt = styles[i];
      final same = (cur.bold == nxt.bold) && (cur.italic == nxt.italic) && (cur.underline == nxt.underline);
      if (same && cur.end >= nxt.start) {
        cur = cur.copyWith(end: nxt.end);
      } else {
        merged.add(cur);
        cur = nxt;
      }
    }
    merged.add(cur);
    styles..clear()..addAll(merged);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.box;

    return Positioned.fill(
      child: Stack(
        children: [
          // Boşluğa basınca kapanır
          Positioned.fill(
            child: GestureDetector(
              onTap: () { widget.onSave(); widget.onClose(); },
              child: Container(color: Colors.black54),
            ),
          ),

          // Panel (içi tıklanınca kapanmasın)
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Önizleme: TextField (tek)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final screenW = constraints.maxWidth;
                      final maxWidth = screenW - 32;

                      final base = GoogleFonts.getFont(
                        b.fontFamily.isEmpty ? "Roboto" : b.fontFamily,
                        textStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
                          fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
                          decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
                          color: Color(b.textColor),
                        ),
                      );

                      final tp = TextPainter(
                        text: TextSpan(text: _controller.text.isEmpty ? "Metin..." : _controller.text, style: base),
                        textAlign: b.align,
                        textDirection: TextDirection.ltr,
                        maxLines: 14,
                      )..layout(maxWidth: maxWidth);

                      final metrics = tp.computeLineMetrics();
                      final lineCount = metrics.length;
                      final w = (tp.width * 1.05 + 32).clamp(80.0, maxWidth); // sonsuz genişlik
                      final h = (lineCount * 23 + 32).clamp(30.0, double.infinity).toDouble(); // satır sayısına göre artış

                      return GestureDetector(
                        onTap: () {}, // panel kapanmasın
                        child: Container(
                          width: w > maxWidth ? maxWidth : w,
                          constraints: BoxConstraints(minHeight: h, maxHeight: h),
                        alignment: Alignment.center,
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              b.borderRadius * (b.width < b.height ? b.width : b.height).clamp(0, 128),
                            ),
                            color: Color(b.backgroundColor).withAlpha(255),
                          ),
                          child: TextField(
                            controller: _controller,
                            focusNode: _focus,
                            maxLines: null,
                            textAlign: b.align,
                            style: GoogleFonts.getFont(
                              b.fontFamily.isEmpty ? "Roboto" : b.fontFamily,
                              textStyle: TextStyle(
                                fontSize: 16,
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
                            onChanged: (val) {
                              // anlık olarak orijinale yaz
                              b.text = val;
                              widget.onUpdate();
                            },
                          ),
                        ),
                      );
                    },
                  ),

                  // Toolbar (tam genişlik)
                  GestureDetector(
                    onTap: () {}, // kapanmasın
                    child: Container(
                      width: double.infinity,
                      color: Colors.grey[900],
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Hizalama
                            IconButton(
                              tooltip: 'Sola hizala',
                              icon: const Icon(Icons.format_align_left, color: Colors.white),
                              onPressed: () { setState(() => b.align = TextAlign.left); widget.onUpdate(); },
                            ),
                            IconButton(
                              tooltip: 'Ortala',
                              icon: const Icon(Icons.format_align_center, color: Colors.white),
                              onPressed: () { setState(() => b.align = TextAlign.center); widget.onUpdate(); },
                            ),
                            IconButton(
                              tooltip: 'Sağa hizala',
                              icon: const Icon(Icons.format_align_right, color: Colors.white),
                              onPressed: () { setState(() => b.align = TextAlign.right); widget.onUpdate(); },
                            ),

                            const SizedBox(width: 8),

                            // Kalın
                            IconButton(
                              tooltip: 'Kalın',
                              icon: Icon(Icons.format_bold, color: b.bold ? Colors.amber : Colors.white),
                              onPressed: () {
                                final sel = _controller.selection;
                                if (sel.isValid && !sel.isCollapsed) {
                                  _toggleInline(field: "bold", start: sel.start, end: sel.end);
                                } else {
                                  b.bold = !b.bold;
                                }
                                setState(() {});
                                widget.onUpdate();
                              },
                            ),

                            // İtalik
                            IconButton(
                              tooltip: 'İtalik',
                              icon: Icon(Icons.format_italic, color: b.italic ? Colors.amber : Colors.white),
                              onPressed: () {
                                final sel = _controller.selection;
                                if (sel.isValid && !sel.isCollapsed) {
                                  _toggleInline(field: "italic", start: sel.start, end: sel.end);
                                } else {
                                  b.italic = !b.italic;
                                  widget.onUpdate();
                                }
                                setState(() {});
                              },
                            ),

                            // Altı çizili
                            IconButton(
                              tooltip: 'Altı Çizili',
                              icon: Icon(Icons.format_underline, color: b.underline ? Colors.amber : Colors.white),
                              onPressed: () {
                                final sel = _controller.selection;
                                if (sel.isValid && !sel.isCollapsed) {
                                  _toggleInline(field: "underline", start: sel.start, end: sel.end);
                                } else {
                                  b.underline = !b.underline;
                                  widget.onUpdate();
                                }
                                setState(() {});
                              },
                            ),

                            const SizedBox(width: 8),

                            // Font seçici
                            IconButton(
                              tooltip: 'Yazı tipi',
                              icon: const Icon(Icons.font_download, color: Colors.white),
                              onPressed: () async {
                                final selected = await showModalBottomSheet<String>(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.grey[950],
                                  builder: (sheet) => SafeArea(
                                    child: ListView.builder(
                                      itemCount: _fonts.length,
                                      itemBuilder: (_, i) {
                                        final f = _fonts[i];
                                        return ListTile(
                                          title: Text(f, style: GoogleFonts.getFont(f, textStyle: const TextStyle(fontSize: 18))),
                                          onTap: () => Navigator.pop(sheet, f),
                                        );
                                      },
                                    ),
                                  ),
                                );
                                if (selected != null && selected.isNotEmpty) {
                                  setState(() {
                                    b.fontFamily = selected;
                                  });
                                  widget.onUpdate();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
