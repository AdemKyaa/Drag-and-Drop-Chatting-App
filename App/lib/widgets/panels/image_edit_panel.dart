// lib/widgets/panels/image_edit_panel.dart
import 'package:flutter/material.dart';
import '../../models/box_item.dart';

class ImageEditPanel extends StatefulWidget {
  final BoxItem box;
  final VoidCallback onUpdate;
  final VoidCallback onSave;
  final VoidCallback? onBringToFront;
  final VoidCallback? onSendToBack;

  const ImageEditPanel({
    super.key,
    required this.box,
    required this.onUpdate,
    required this.onSave,
    this.onBringToFront,
    this.onSendToBack,
  });

  @override
  State<ImageEditPanel> createState() => _ImageEditPanelState();
}

class _ImageEditPanelState extends State<ImageEditPanel> {
  late BoxItem b;

  @override
  void initState() {
    super.initState();
    b = widget.box; // 'b' undefined hataları böyle biter
  }
  
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
                  value: b.imageOpacity,
                  min: 0,
                  max: 1,
                  onChanged: (v) {
                    setState(() {
                      b.imageOpacity = v;
                    });
                    widget.onUpdate();
                  },
                  onChangeEnd: (_) => widget.onSave(),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onBringToFront,
                  child: const Text("En Üste Al"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onSendToBack,
                  child: const Text("En Alta Al"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}