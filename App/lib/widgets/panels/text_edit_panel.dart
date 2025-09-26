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
  final bool isDarkMode; // ✅ Dark mode bilgisi

  const TextEditPanel({
    super.key,
    required this.box,
    required this.onUpdate,
    required this.onSave,
    this.onBringToFront,
    this.onSendToBack,
    required this.isDarkMode,
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
      builder: (_) {
        final bgColor =
            widget.isDarkMode ? Colors.grey[900] : Colors.white;
        final textColor =
            widget.isDarkMode ? Colors.white : Colors.black;

        return AlertDialog(
          backgroundColor: bgColor,
          title: Text(title, style: TextStyle(color: textColor)),
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
              child: Text("İptal", style: TextStyle(color: textColor)),
            ),
            TextButton(
              onPressed: () {
                onSelected(temp);
                Navigator.pop(context);
              },
              child: Text("Seç", style: TextStyle(color: textColor)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.box;

    final bgColor = widget.isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: const [
            BoxShadow(blurRadius: 12, color: Colors.black26),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Metin Ayarları",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),

            // 🔹 Arka Plan Rengi
            Row(
              children: [
                Text("Arka Plan Rengi", style: TextStyle(color: textColor)),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: Icon(Icons.color_lens, color: textColor),
                  label: Text("Seç", style: TextStyle(color: textColor)),
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
                Text("BG Opacity", style: TextStyle(color: textColor)),
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
                Text("Radius (%)", style: TextStyle(color: textColor)),
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
                Text("Metin Rengi", style: TextStyle(color: textColor)),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: Icon(Icons.color_lens, color: textColor),
                  label: Text("Seç", style: TextStyle(color: textColor)),
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

            // 🔹 Z-Order butonları
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.vertical_align_top, color: textColor),
                    label: Text("En Üste Al", style: TextStyle(color: textColor)),
                    onPressed: widget.onBringToFront,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.vertical_align_bottom, color: textColor),
                    label: Text("En Alta Al", style: TextStyle(color: textColor)),
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
