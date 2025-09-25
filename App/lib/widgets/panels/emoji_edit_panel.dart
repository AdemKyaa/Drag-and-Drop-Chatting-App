import 'package:flutter/material.dart';
import '../../models/box_item.dart';

class EmojiEditPanel extends StatelessWidget {
  final BoxItem box;
  final VoidCallback onUpdate;
  final VoidCallback onSave;
  final VoidCallback onClose;
  final VoidCallback onBringToFront;
  final VoidCallback onSendToBack;

  const EmojiEditPanel({
    super.key,
    required this.box,
    required this.onUpdate,
    required this.onSave,
    required this.onClose,
    required this.onBringToFront,
    required this.onSendToBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Text("Opacity", style: TextStyle(color: Colors.white)),
          Expanded(
            child: Slider(
              value: box.opacity,
              min: 0.0,
              max: 1.0,
              divisions: null, // ✅ ara kilit noktası yok
              onChanged: (val) {
                box.opacity = val;
                onUpdate();
              },
            ),
          ),
          IconButton(
            tooltip: "En üste al",
            icon: const Icon(Icons.vertical_align_top, color: Colors.white),
            onPressed: onBringToFront,
          ),
          IconButton(
            tooltip: "En alta al",
            icon: const Icon(Icons.vertical_align_bottom, color: Colors.white),
            onPressed: onSendToBack,
          ),
        ],
      ),
    );
  }
}
