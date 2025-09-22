// lib/widgets/panels/image_edit_panel.dart
import 'package:flutter/material.dart';
import '../../models/box_item.dart';

class ImageEditPanel extends StatelessWidget {
  final BoxItem box;
  final VoidCallback onSave;
  final VoidCallback? onUpdate;

  const ImageEditPanel({
    super.key,
    required this.box,
    required this.onSave,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Resim Ayarları",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    box.z = DateTime.now().millisecondsSinceEpoch;
                    onSave();
                    onUpdate?.call();
                    Navigator.pop(context);
                  },
                  child: const Text("En üste"),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    box.z = -DateTime.now().millisecondsSinceEpoch;
                    onSave();
                    onUpdate?.call();
                    Navigator.pop(context);
                  },
                  child: const Text("En alta"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
