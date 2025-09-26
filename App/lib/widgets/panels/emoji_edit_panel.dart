import 'package:flutter/material.dart';
import '../../models/box_item.dart';

class EmojiEditPanel extends StatelessWidget {
  final BoxItem box;
  final VoidCallback onUpdate;
  final Future<void> Function() onSave;
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
      color: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Opacity Slider
          const Text("Opacity"),
          Expanded(
            child: Slider(
              value: box.opacity,
              onChanged: (v) {
                box.opacity = v;
                onUpdate();
              },
              min: 0.0,
              max: 1.0,
            ),
          ),

          IconButton(
            icon: const Icon(Icons.vertical_align_top),
            tooltip: "En üste al",
            onPressed: onBringToFront,
          ),
          IconButton(
            icon: const Icon(Icons.vertical_align_bottom),
            tooltip: "En alta al",
            onPressed: onSendToBack,
          ),

          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}
