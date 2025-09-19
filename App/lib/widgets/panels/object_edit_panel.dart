import 'package:flutter/material.dart';
import '../../models/box_item.dart';

class ObjectEditPanel extends StatelessWidget {
  final BoxItem box;
  final VoidCallback onSave;

  const ObjectEditPanel({super.key, required this.box, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Obje Ayarları", style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    box.z = DateTime.now().millisecondsSinceEpoch;
                    onSave();
                  },
                  child: const Text("En üste"),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    box.z = -DateTime.now().millisecondsSinceEpoch;
                    onSave();
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
