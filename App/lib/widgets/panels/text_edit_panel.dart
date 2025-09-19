import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/box_item.dart';

class TextEditPanel extends StatefulWidget {
  final BoxItem box;
  final VoidCallback onUpdate;
  final VoidCallback onSave;
  int colorToInt(Color c) => (c.alpha << 24) | (c.red << 16) | (c.green << 8) | c.blue;
  
  const TextEditPanel({
    super.key,
    required this.box,
    required this.onUpdate,
    required this.onSave,
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

  @override
  Widget build(BuildContext context) {
    final b = widget.box;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                    Color temp = Color(localBgColor);
                    await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Arka Plan Rengi"),
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
                              setState(() {
                                localBgColor = temp.value;
                                b.backgroundColor = localBgColor;
                              });
                              widget.onUpdate();
                              widget.onSave();
                              Navigator.pop(context);
                            },
                            child: const Text("Seç"),
                          ),
                        ],
                      ),
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
                    Color temp = Color(localTextColor);
                    await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Metin Rengi"),
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
                              setState(() {
                                localTextColor = temp.value;
                                b.textColor = localTextColor;
                              });
                              widget.onUpdate();
                              widget.onSave();
                              Navigator.pop(context);
                            },
                            child: const Text("Seç"),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),

            // 🔹 Hizalama Butonları
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.format_align_left),
                  onPressed: () {
                    b.align = TextAlign.left;
                    widget.onUpdate();
                    widget.onSave();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.format_align_center),
                  onPressed: () {
                    b.align = TextAlign.center;
                    widget.onUpdate();
                    widget.onSave();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.format_align_right),
                  onPressed: () {
                    b.align = TextAlign.right;
                    widget.onUpdate();
                    widget.onSave();
                  },
                ),
              ],
            ),

            // 🔹 Kapat
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                child: const Text("Kapat"),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
