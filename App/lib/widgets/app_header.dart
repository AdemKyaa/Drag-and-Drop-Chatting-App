import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final String username;
  final VoidCallback onAddText;
  final VoidCallback onAddImage;

  const AppHeader({
    super.key,
    required this.username,
    required this.onAddText,
    required this.onAddImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text("👤 $username",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.text_fields),
            tooltip: "Metin Ekle",
            onPressed: onAddText,
          ),
          IconButton(
            icon: const Icon(Icons.image),
            tooltip: "Resim Ekle",
            onPressed: onAddImage,
          ),
        ],
      ),
    );
  }
}
