import 'package:flutter/material.dart';

class DeleteArea extends StatelessWidget {
  final bool isActive;
  final VoidCallback? onDrop;              // ✅ onAccept yerine onDrop
  final ValueChanged<bool>? onOverChange;  // hover/over bildirimi için

  const DeleteArea({
    super.key,
    required this.isActive,
    this.onDrop,
    this.onOverChange,
  });

  @override
  Widget build(BuildContext context) {
    const base = Colors.red;
    final bg = base.withAlpha((isActive ? 0.15 : 0.08) * 255 ~/ 1); // ✅ withOpacity yerine withAlpha

    return DragTarget<Object>(
      onWillAcceptWithDetails: (_) {
        onOverChange?.call(true);
        return true;
      },
      onLeave: (_) => onOverChange?.call(false),
      onAcceptWithDetails: (_) {                       // DragTarget’ın kendi onAccept’i
        onOverChange?.call(false);
        onDrop?.call();
      },
      builder: (_, __, ___) {
        return Container(
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            border: Border(top: BorderSide(color: base.withAlpha(64))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete, color: base),
              const SizedBox(width: 8),
              Text(
                isActive ? "Bırakırsan silinir" : "Buraya sürükleyip bırak → sil",
                style: TextStyle(color: base),
              ),
            ],
          ),
        );
      },
    );
  }
}
