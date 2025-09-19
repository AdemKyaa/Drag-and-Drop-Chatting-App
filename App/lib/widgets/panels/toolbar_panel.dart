import 'package:flutter/material.dart';

class ToolbarPanel extends StatelessWidget {
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;

  const ToolbarPanel({
    super.key,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          IconButton(onPressed: onBold, icon: const Icon(Icons.format_bold)),
          IconButton(onPressed: onItalic, icon: const Icon(Icons.format_italic)),
          IconButton(onPressed: onUnderline, icon: const Icon(Icons.format_underline)),
        ],
      ),
    );
  }
}
