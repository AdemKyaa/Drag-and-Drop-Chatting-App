import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/box_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- Diller ---
const Map<String, Map<String, String>> _emojiPanelTranslations = {
  'en': {
    'bringFront': 'Bring to Front',
    'sendBack': 'Send to Back',
    'opacity': 'Opacity',
  },
  'tr': {
    'bringFront': 'En üste al',
    'sendBack': 'En alta al',
    'opacity': 'Opaklık',
  },
};

String et(String lang, String key) {
  return _emojiPanelTranslations[lang]?[key] ?? key;
}

class EmojiEditPanel extends StatefulWidget {
  final BoxItem box;
  final VoidCallback onUpdate;
  final Future<void> Function() onSave;
  final VoidCallback onClose;
  final VoidCallback? onBringToFront;
  final VoidCallback? onSendToBack;
  final String currentUserId;

  const EmojiEditPanel({
    super.key,
    required this.box,
    required this.onUpdate,
    required this.onSave,
    required this.onClose,
    this.onBringToFront,
    this.onSendToBack,
    required this.currentUserId,
  });

  @override
  State<EmojiEditPanel> createState() => _EmojiEditPanelState();
}

class _EmojiEditPanelState extends State<EmojiEditPanel> {
  Timer? _debouncer;

  void _scheduleAutoSave() {
    _debouncer?.cancel();
    _debouncer = Timer(const Duration(milliseconds: 250), () {
      widget.onSave();
    });
  }

  @override
  void dispose() {
    _debouncer?.cancel();
    super.dispose();
  }

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
        final bool isDarkMode = data['isDarkMode'] ?? false;
        final int seed = (data['themeColor'] as int?) ?? 0xFF2962FF;
        final String lang = data['lang'] ?? 'tr'; // 🔹 dili oku

        final background = isDarkMode ? Colors.grey[900] : Colors.grey[50];
        final cardColor = isDarkMode ? Colors.grey[850]! : Colors.white;
        final textColor = isDarkMode ? Colors.white : Colors.black;
        final themeColor = Color(seed);

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: background,
            boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26)],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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

                // Z-Order buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.tonal(
                      onPressed: widget.onBringToFront,
                      style: FilledButton.styleFrom(
                        backgroundColor: cardColor,
                        foregroundColor: textColor,
                      ),
                      child: Text(et(lang, 'bringFront')),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonal(
                      onPressed: widget.onSendToBack,
                      style: FilledButton.styleFrom(
                        backgroundColor: cardColor,
                        foregroundColor: textColor,
                      ),
                      child: Text(et(lang, 'sendBack')),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Opacity slider
                Row(
                  children: [
                    Text(et(lang, 'opacity'), style: TextStyle(color: textColor)),
                    Expanded(
                      child: Slider(
                        value: b.opacity.clamp(0.0, 1.0),
                        min: 0.0,
                        max: 1.0,
                        divisions: 100,
                        activeColor: themeColor,
                        inactiveColor: textColor.withOpacity(0.3),
                        label: (b.opacity * 100).toStringAsFixed(0),
                        onChanged: (v) {
                          setState(() => b.opacity = v);
                          widget.onUpdate();
                          _scheduleAutoSave();
                        },
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
