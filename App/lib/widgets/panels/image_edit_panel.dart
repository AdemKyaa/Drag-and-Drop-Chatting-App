// lib/widgets/panels/image_edit_panel.dart
import 'package:flutter/material.dart';
import '../../models/box_item.dart';

class ImageEditPanel extends StatefulWidget {
  final BoxItem box;
  final VoidCallback onUpdate;
  final VoidCallback onSave;

  const ImageEditPanel({
    super.key,
    required this.box,
    required this.onUpdate,
    required this.onSave,
  });

  @override
  State<ImageEditPanel> createState() => _ImageEditPanelState();
}

class _ImageEditPanelState extends State<ImageEditPanel> {
  @override
  Widget build(BuildContext context) {
    final b = widget.box;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Radius slider
          Row(
            children: [
              const Text("Radius"),
              Expanded(
                child: Slider(
                  value: b.borderRadius,
                  min: 0,
                  max: 1,
                  onChanged: (v) {
                    setState(() {
                      b.borderRadius = v;
                    });
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
              const Text("Opacity"),
              Expanded(
                child: Slider(
                  value: b.backgroundOpacity,
                  min: 0,
                  max: 1,
                  onChanged: (v) {
                    setState(() {
                      b.backgroundOpacity = v;
                    });
                    widget.onUpdate();
                  },
                  onChangeEnd: (_) => widget.onSave(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
