import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/box_item.dart';

class EmojiEditPanel extends StatefulWidget {
  final BoxItem box;
  final VoidCallback onUpdate;
  final Future<void> Function() onSave;
  final VoidCallback onClose;
  final VoidCallback? onBringToFront;
  final VoidCallback? onSendToBack;

  const EmojiEditPanel({
    super.key,
    required this.box,
    required this.onUpdate,
    required this.onSave,
    required this.onClose,
    this.onBringToFront,
    this.onSendToBack,
  });

  @override
  State<EmojiEditPanel> createState() => _EmojiEditPanelState();
}

class _EmojiEditPanelState extends State<EmojiEditPanel> {
  Timer? _debouncer;

  void _scheduleAutoSave() {
    _debouncer?.cancel();
    _debouncer = Timer(const Duration(milliseconds: 250), () {
      widget.onSave(); // otomatik kaydet
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

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26)],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black26, borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Z-Order butonları (aynı davranış, sadece görsel düzen)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonal(
                  onPressed: widget.onBringToFront,
                  child: const Text('En üste al'),
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: widget.onSendToBack,
                  child: const Text('En alta al'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Opaklık (0..1), “kilit” yok – düz slider
            Row(
              children: [
                const Text('Opaklık'),
                Expanded(
                  child: Slider(
                    value: b.opacity.clamp(0.0, 1.0),
                    min: 0.0,
                    max: 1.0,
                    divisions: 100, // pürüzsüz his
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
  }
}
