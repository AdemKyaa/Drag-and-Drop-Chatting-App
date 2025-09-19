import 'package:flutter/material.dart';

class UserTile extends StatelessWidget {
  final String username;
  final bool isOnline;
  final VoidCallback onTap;

  const UserTile({
    super.key,
    required this.username,
    required this.isOnline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isOnline ? Colors.green : Colors.grey,
        child: Text(username[0].toUpperCase()),
      ),
      title: Text(username),
      trailing: Icon(
        isOnline ? Icons.circle : Icons.circle_outlined,
        color: isOnline ? Colors.green : Colors.grey,
        size: 12,
      ),
      onTap: onTap,
    );
  }
}
