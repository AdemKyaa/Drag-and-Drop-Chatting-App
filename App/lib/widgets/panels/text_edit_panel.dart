// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/box_item.dart';

class TextEditPanel extends StatefulWidget {
  final BoxItem box;
  final VoidCallback onUpdate;
  final VoidCallback onSave;
  final VoidCallback? onBringToFront;
  final VoidCallback? onSendToBack;

  const TextEditPanel({
    super.key,
    required this.box,
    required this.onUpdate,
    required this.onSave,
    this.onBringToFront,
    this.onSendToBack,
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
  }) async {
    Color temp = current;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
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
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () {
              onSelected(temp);
              Navigator.pop(context);
            },
            child: const Text("Seç"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.box;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Metin Ayarları",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),

            // 🔹 Arka Plan Rengi
            Row(
              children: [
                const Text("Arka Plan Rengi"),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.color_lens),
                  label: const Text("Seç"),
                  onPressed: () async {
                    await _pickColor(
                      title: "Arka Plan Rengi",
                      current: Color(localBgColor),
                      onSelected: (c) {
                        setState(() {
                          localBgColor = c.value;
                          b.backgroundColor = localBgColor;
                        });
                        widget.onUpdate();
                        widget.onSave();
                      },
                    );
                  },
                ),
              ],
            ),

            // 🔹 Arka Plan Opaklığı
            Row(
              children: [
                const Text("BG Opacity"),
                Expanded(
                  child: Slider(
                    value: localBgOpacity,
                    min: 0,
                    max: 1,
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
                const Text("Radius (%)"),
                Expanded(
                  child: Slider(
                    value: localRadiusFactor,
                    min: 0,
                    max: 0.5,
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
                const Text("Metin Rengi"),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.color_lens),
                  label: const Text("Seç"),
                  onPressed: () async {
                    await _pickColor(
                      title: "Metin Rengi",
                      current: Color(localTextColor),
                      onSelected: (c) {
                        setState(() {
                          localTextColor = c.value;
                          b.textColor = localTextColor;
                        });
                        widget.onUpdate();
                        widget.onSave();
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.vertical_align_top),
                    label: const Text("En Üste Al"),
                    onPressed: widget.onBringToFront,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.vertical_align_bottom),
                    label: const Text("En Alta Al"),
                    onPressed: widget.onSendToBack,
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