import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/user_tile.dart';
import 'chat_screen.dart';

class UserListScreen extends StatelessWidget {
  final String currentUserId;

  const UserListScreen({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final users = FirebaseFirestore.instance.collection("users");

    return Scaffold(
      appBar: AppBar(title: const Text("Kullanıcılar")),
      body: StreamBuilder<QuerySnapshot>(
        stream: users.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          return ListView(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return UserTile(
                username: data["username"],
                isOnline: data["isOnline"] ?? false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        currentUserId: currentUserId,
                        otherUserId: doc.id,
                        otherUsername: data["username"],
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
