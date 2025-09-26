import 'package:flutter/material.dart';

class DeleteArea extends StatelessWidget {
  final bool isActive;
  final VoidCallback? onDrop;
  final ValueChanged<bool>? onOverChange;

  const DeleteArea({
    super.key,
    required this.isActive,
    this.onDrop,
    this.onOverChange,
  });

  @override
  Widget build(BuildContext context) {
    const base = Colors.red;

    return AnimatedScale(
      scale: isActive ? 1.3 : 1.0, // üzerine gelince büyüsün
      duration: const Duration(milliseconds: 50),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: isActive ? const Color.fromARGB(50, 244, 67, 54) : const Color.fromARGB(50, 244, 67, 54),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.delete, color: base, size: 32),
      ),
    );
  }
}
