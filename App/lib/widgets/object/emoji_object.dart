import 'package:flutter/material.dart';
import '../../models/box_item.dart';

class EmojiObject extends StatelessWidget {
  final BoxItem box;
  const EmojiObject({super.key, required this.box});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: box.rotation,
      child: Opacity(
        opacity: box.opacity,
        child: Text(
          box.text,
          style: TextStyle(fontSize: box.fontSize),
        ),
      ),
    );
  }
}
