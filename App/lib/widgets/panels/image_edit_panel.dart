// lib/widgets/panels/image_edit_panel.dart
import 'package:flutter/material.dart';
import '../../models/box_item.dart';

class ImageEditPanel extends StatefulWidget {
  final BoxItem box;
  final VoidCallback onUpdate;
  final VoidCallback onSave;
  final VoidCallback? onBringToFront;
  final VoidCallback? onSendToBack;
  final bool isDarkMode; // ✅ Dark mode bilgisi parametreyle geliyor

  const ImageEditPanel({
    super.key,
    required this.box,
    required this.onUpdate,
    required this.onSave,
    this.onBringToFront,
    this.onSendToBack,
    required this.isDarkMode,
  });

  @override
  State<ImageEditPanel> createState() => _ImageEditPanelState();
}

class _ImageEditPanelState extends State<ImageEditPanel> {
  late BoxItem b;

  @override
  void initState() {
    super.initState();
    b = widget.box;
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.box;
    final isDarkMode = widget.isDarkMode;

    final background = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;

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
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Radius slider
            Row(
              children: [
                Text("Radius", style: TextStyle(color: textColor)),
                Expanded(
                  child: Slider(
                    value: b.borderRadius,
                    min: 0,
                    max: 1,
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
                Text("Opacity", style: TextStyle(color: textColor)),
                Expanded(
                  child: Slider(
                    value: b.imageOpacity,
                    min: 0,
                    max: 1,
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

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onBringToFront,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: textColor.withOpacity(0.5)),
                    ),
                    child: const Text("En Üste Al"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onSendToBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: textColor.withOpacity(0.5)),
                    ),
                    child: const Text("En Alta Al"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
