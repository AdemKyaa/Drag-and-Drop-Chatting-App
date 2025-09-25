import 'package:flutter/material.dart';
import '../../models/box_item.dart';

class EmojiEditPanel extends StatelessWidget {
  final BoxItem box;
  final VoidCallback onUpdate;
  final VoidCallback onSave;
  final VoidCallback onClose;

  const EmojiEditPanel({
    super.key,
    required this.box,
    required this.onUpdate,
    required this.onSave,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Boyut ayarı
          Row(
            children: [
              const Text("Size"),
              Expanded(
                child: Slider(
                  min: 16,
                  max: 200,
                  value: box.fontSize,
                  onChanged: (v) {
                    box.fontSize = v;
                    onUpdate();
                  },
                  onChangeEnd: (_) => onSave(),
                ),
              ),
              Text("${box.fontSize.toInt()}"),
            ],
          ),

          // Opacity ayarı
          Row(
            children: [
              const Text("Opacity"),
              Expanded(
                child: Slider(
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  value: box.opacity,
                  onChanged: (v) {
                    box.opacity = v;
                    onUpdate();
                  },
                  onChangeEnd: (_) => onSave(),
                ),
              ),
              Text("${(box.opacity * 100).toInt()}%"),
            ],
          ),

          // Katman kontrolü
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  box.z += 1; // en üste taşı
                  onUpdate();
                  onSave();
                },
                child: const Text("Bring Front"),
              ),
              ElevatedButton(
                onPressed: () {
                  box.z -= 1; // en alta gönder
                  onUpdate();
                  onSave();
                },
                child: const Text("Send Back"),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Panel kapatma butonu
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onClose,
              child: const Text("Close"),
            ),
          ),
        ],
      ),
    );
  }
}
