import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
            children: docs.where((u) => u.id != currentUserId).map((user) {
              final data = user.data() as Map<String, dynamic>;
              final isOnline = data["isOnline"] == true;
              final hasNewMessage = data.containsKey("hasNewMessage")
                  ? data["hasNewMessage"] == true
                  : false;

              return ListTile(
                onTap: () {
                  // giriş yapan kullanıcının "yeni mesaj" durumunu temizle
                  users.doc(currentUserId).update({"hasNewMessage": false});

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        currentUserId: currentUserId,
                        otherUserId: user.id,
                        otherUsername: data["username"],
                      ),
                    ),
                  );
                },
                leading: CircleAvatar(
                  radius: 8,
                  backgroundColor: isOnline ? Colors.green : Colors.grey,
                ),
                title: Text(data["username"] ?? ""),
                trailing: hasNewMessage
                    ? const Icon(Icons.circle, color: Colors.red, size: 12)
                    : null,
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
