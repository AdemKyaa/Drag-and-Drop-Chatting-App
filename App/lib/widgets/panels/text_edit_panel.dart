// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/box_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- Diller ---
const Map<String, Map<String, String>> _textPanelTranslations = {
  'en': {
    'title': 'Text Settings',
    'bgColor': 'Background Color',
    'select': 'Select',
    'bgOpacity': 'Background Opacity',
    'radius': 'Radius (%)',
    'textColor': 'Text Color',
    'bringFront': 'Bring to Front',
    'sendBack': 'Send to Back',
    'cancel': 'Cancel',
  },
  'tr': {
    'title': 'Metin Ayarları',
    'bgColor': 'Arka Plan Rengi',
    'select': 'Seç',
    'bgOpacity': 'Arka Plan Opaklığı',
    'radius': 'Köşe Yumuşatma (%)',
    'textColor': 'Metin Rengi',
    'bringFront': 'En Üste Al',
    'sendBack': 'En Alta Al',
    'cancel': 'İptal',
  },
};

String tt(String lang, String key) {
  return _textPanelTranslations[lang]?[key] ?? key;
}

class TextEditPanel extends StatefulWidget {
  final BoxItem box;
  final VoidCallback onUpdate;
  final VoidCallback onSave;
  final VoidCallback? onBringToFront;
  final VoidCallback? onSendToBack;
  final bool isDarkMode;
  final String currentUserId;

  const TextEditPanel({
    super.key,
    required this.box,
    required this.onUpdate,
    required this.onSave,
    this.onBringToFront,
    this.onSendToBack,
    required this.isDarkMode,
    required this.currentUserId,
  });

  @override
  State<TextEditPanel> createState() => _TextEditPanelState();
}

class _TextEditPanelState extends State<TextEditPanel> {
  late double localRadiusFactor;
  late double localBgOpacity;
  late int localBgColor;
  late int localTextColor;

  @override
  void initState() {
    super.initState();
    localRadiusFactor = widget.box.borderRadius;
    localBgOpacity = widget.box.backgroundOpacity;
    localBgColor = widget.box.backgroundColor;
    localTextColor = widget.box.textColor;
  }

  Future<void> _pickColor({
    required String title,
    required Color current,
    required void Function(Color c) onSelected,
    required String lang,
  }) async {
    Color temp = current;
    await showDialog(
      context: context,
      builder: (_) {
        final background = widget.isDarkMode
            ? const Color(0xFF1B2E24)
            : const Color(0xFFB9DFC1);

        final textColor = widget.isDarkMode
            ? const Color(0xFFE6F2E9)
            : const Color(0xFF1B3C2E);

        return AlertDialog(
          backgroundColor: background,
          title: Text(title, style: TextStyle(color: textColor)),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: temp,
              onColorChanged: (c) => temp = c,
              paletteType: PaletteType.hsvWithHue,
              enableAlpha: false,
              displayThumbColor: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tt(lang, 'cancel'), style: TextStyle(color: textColor)),
            ),
            TextButton(
              onPressed: () {
                onSelected(temp);
                Navigator.pop(context);
              },
              child: Text(tt(lang, 'select'), style: TextStyle(color: textColor)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.box;

    final isDark = widget.isDarkMode;
    final background = isDark
        ? const Color(0xFF0D1A13) // Çok koyu yeşil / siyaha yakın
        : const Color(0xFFB9DFC1); // Açık pastel yeşil

    final cardColor = isDark
        ? const Color(0xFF1B2E24)
        : const Color(0xFF9CC5A4);

    final textColor = isDark
        ? const Color(0xFFE6F2E9)
        : const Color(0xFF1B3C2E);

    const themeColor = Color(0xFF4CAF50); // canlı yeşil

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final String lang = data['lang'] ?? 'tr';

        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: const [
                BoxShadow(blurRadius: 12, color: Colors.black26),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tt(lang, 'title'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),

                // 🔹 Arka Plan Rengi
                Row(
                  children: [
                    Text(tt(lang, 'bgColor'), style: TextStyle(color: textColor)),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: Icon(Icons.color_lens, color: textColor),
                      label: Text(tt(lang, 'select'),
                          style: TextStyle(color: textColor)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: textColor.withOpacity(0.5)),
                        backgroundColor: cardColor,
                      ),
                      onPressed: () async {
                        await _pickColor(
                          title: tt(lang, 'bgColor'),
                          current: Color(localBgColor),
                          onSelected: (c) {
                            setState(() {
                              localBgColor = c.value;
                              b.backgroundColor = localBgColor;
                            });
                            widget.onUpdate();
                            widget.onSave();
                          },
                          lang: lang,
                        );
                      },
                    ),
                  ],
                ),

                // 🔹 Arka Plan Opaklığı
                Row(
                  children: [
                    Text(tt(lang, 'bgOpacity'), style: TextStyle(color: textColor)),
                    Expanded(
                      child: Slider(
                        value: localBgOpacity,
                        min: 0,
                        max: 1,
                        activeColor: themeColor,
                        inactiveColor: textColor.withOpacity(0.3),
                        onChanged: (v) {
                          setState(() => localBgOpacity = v);
                          b.backgroundOpacity = v;
                          widget.onUpdate();
                          widget.onSave();
                        },
                      ),
                    ),
                  ],
                ),

                // 🔹 Köşe Yumuşatma
                Row(
                  children: [
                    Text(tt(lang, 'radius'), style: TextStyle(color: textColor)),
                    Expanded(
                      child: Slider(
                        value: localRadiusFactor,
                        min: 0,
                        max: 0.5,
                        activeColor: themeColor,
                        inactiveColor: textColor.withOpacity(0.3),
                        onChanged: (v) {
                          setState(() => localRadiusFactor = v);
                          b.borderRadius = v;
                          widget.onUpdate();
                          widget.onSave();
                        },
                      ),
                    ),
                  ],
                ),

                // 🔹 Metin Rengi
                Row(
                  children: [
                    Text(tt(lang, 'textColor'), style: TextStyle(color: textColor)),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: Icon(Icons.color_lens, color: textColor),
                      label: Text(tt(lang, 'select'),
                          style: TextStyle(color: textColor)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: textColor.withOpacity(0.5)),
                        backgroundColor: cardColor,
                      ),
                      onPressed: () async {
                        await _pickColor(
                          title: tt(lang, 'textColor'),
                          current: Color(localTextColor),
                          onSelected: (c) {
                            setState(() {
                              localTextColor = c.value;
                              b.textColor = localTextColor;
                            });
                            widget.onUpdate();
                            widget.onSave();
                          },
                          lang: lang,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 🔹 Z-Order butonları
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.vertical_align_top, color: textColor),
                        label: Text(tt(lang, 'bringFront'),
                            style: TextStyle(color: textColor)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: textColor.withOpacity(0.5)),
                          backgroundColor: cardColor,
                        ),
                        onPressed: widget.onBringToFront,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.vertical_align_bottom, color: textColor),
                        label: Text(tt(lang, 'sendBack'),
                            style: TextStyle(color: textColor)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: textColor.withOpacity(0.5)),
                          backgroundColor: cardColor,
                        ),
                        onPressed: widget.onSendToBack,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
