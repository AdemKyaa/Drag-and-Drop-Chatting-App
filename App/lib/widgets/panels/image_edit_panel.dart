// lib/widgets/panels/image_edit_panel.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/box_item.dart';

// --- Diller ---
const Map<String, Map<String, String>> _imagePanelTranslations = {
  'en': {
    'radius': 'Radius',
    'opacity': 'Opacity',
    'bringFront': 'Bring to Front',
    'sendBack': 'Send to Back',
  },
  'tr': {
    'radius': 'Köşe Yumuşatma',
    'opacity': 'Opaklık',
    'bringFront': 'En Üste Al',
    'sendBack': 'En Alta Al',
  },
};

String it(String lang, String key) {
  return _imagePanelTranslations[lang]?[key] ?? key;
}

class ImageEditPanel extends StatefulWidget {
  final BoxItem box;
  final VoidCallback onUpdate;
  final VoidCallback onSave;
  final VoidCallback? onBringToFront;
  final VoidCallback? onSendToBack;
  final bool isDarkMode;
  final String currentUserId;

  const ImageEditPanel({
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
  State<ImageEditPanel> createState() => _ImageEditPanelState();
}

class _ImageEditPanelState extends State<ImageEditPanel> {
  @override
  Widget build(BuildContext context) {
    final b = widget.box;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final lang = data['lang'] ?? 'tr';

        final isDarkMode = widget.isDarkMode;

        // ✅ Yeşil palete uygun renkler
        final background = isDarkMode
            ? const Color(0xFF0D1A13) // Çok koyu yeşil / siyaha yakın
            : const Color(0xFFB9DFC1); // Açık pastel yeşil

        final cardColor = isDarkMode
            ? const Color(0xFF1B2E24) // Dark mode kart
            : const Color(0xFF9CC5A4); // Light mode kart

        final textColor = isDarkMode
            ? const Color(0xFFE6F2E9) // Açık yazı
            : const Color(0xFF1B3C2E); // Koyu yazı

        const themeColor = Color(0xFF4CAF50); // Canlı yeşil slider

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Radius slider
                Row(
                  children: [
                    Text(it(lang, 'radius'), style: TextStyle(color: textColor)),
                    Expanded(
                      child: Slider(
                        value: b.borderRadius,
                        min: 0,
                        max: 1,
                        activeColor: themeColor,
                        inactiveColor: textColor.withOpacity(0.3),
                        onChanged: (v) {
                          setState(() => b.borderRadius = v);
                          widget.onUpdate();
                        },
                        onChangeEnd: (_) => widget.onSave(),
                      ),
                    ),
                  ],
                ),

                // Opacity slider
                Row(
                  children: [
                    Text(it(lang, 'opacity'), style: TextStyle(color: textColor)),
                    Expanded(
                      child: Slider(
                        value: b.imageOpacity,
                        min: 0,
                        max: 1,
                        activeColor: themeColor,
                        inactiveColor: textColor.withOpacity(0.3),
                        onChanged: (v) {
                          setState(() => b.imageOpacity = v);
                          widget.onUpdate();
                        },
                        onChangeEnd: (_) => widget.onSave(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Z-order buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onBringToFront,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: BorderSide(color: textColor.withOpacity(0.5)),
                          backgroundColor: cardColor,
                        ),
                        child: Text(it(lang, 'bringFront')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onSendToBack,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: BorderSide(color: textColor.withOpacity(0.5)),
                          backgroundColor: cardColor,
                        ),
                        child: Text(it(lang, 'sendBack')),
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
