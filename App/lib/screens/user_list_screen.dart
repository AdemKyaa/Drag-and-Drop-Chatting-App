import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class UserListScreen extends StatelessWidget {
  final String currentUserId;

  const UserListScreen({super.key, required this.currentUserId});

  // Arkadaş ekleme işlemi
  Future<void> _addFriend(BuildContext context) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Arkadaş Ekle"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Kullanıcı adını gir",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () async {
              final username = controller.text.trim();
              if (username.isEmpty) return;

              // Firestore'da username ile ara
              final snap = await FirebaseFirestore.instance
                  .collection("users")
                  .where("displayName", isEqualTo: username)
                  .get();

              if (snap.docs.isNotEmpty) {
                final friendId = snap.docs.first.id;

                await FirebaseFirestore.instance
                    .collection("friends")
                    .doc(currentUserId)
                    .collection("list")
                    .doc(friendId)
                    .set({"addedAt": FieldValue.serverTimestamp()});

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Kullanıcı bulunamadı")),
                );
              }
            },
            child: const Text("Ekle"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendsRef = FirebaseFirestore.instance
        .collection("friends")
        .doc(currentUserId)
        .collection("list");

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection("users").doc(currentUserId).snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() ?? {};
        final bool isDarkMode = userData["isDarkMode"] ?? false;
        final int seed = (userData["themeColor"] as int?) ?? 0xFF2962FF;

        final background = isDarkMode ? Colors.grey[900] : Colors.grey[50];
        final cardColor = isDarkMode ? Colors.black : Colors.white;
        final textColor = isDarkMode ? Colors.white : Colors.black;
        final themeColor = Color(seed);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: cardColor,
            foregroundColor: textColor,
            iconTheme: IconThemeData(color: textColor),
            title: Text("Arkadaşlar", style: TextStyle(color: textColor)),
            actions: [
              IconButton(
                icon: Icon(Icons.settings, color: textColor),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(currentUserId: currentUserId),
                    ),
                  );
                },
              ),
            ],
          ),
          backgroundColor: background,
          body: StreamBuilder<QuerySnapshot>(
            stream: friendsRef.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final friends = snapshot.data!.docs;

              if (friends.isEmpty) {
                return Center(
                  child: Text(
                    "Henüz arkadaş eklemediniz.",
                    style: TextStyle(color: textColor),
                  ),
                );
              }

              return ListView.builder(
                itemCount: friends.length,
                itemBuilder: (ctx, i) {
                  final friendId = friends[i].id;

                  // Arkadaş bilgilerini users tablosundan çekiyoruz
                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("users")
                        .doc(friendId)
                        .snapshots(),
                    builder: (ctx, userSnap) {
                      if (!userSnap.hasData) {
                        return const SizedBox.shrink();
                      }
                      final data = userSnap.data!.data() as Map<String, dynamic>?;

                      if (data == null) return const SizedBox.shrink();

                      final name = data["displayName"] ?? "Bilinmiyor";
                      final photoUrl = data["photoUrl"] as String?;
                      final isOnline = data["isOnline"] ?? false;
                      final visible = data["isOnlineVisible"] ?? true;

                      Widget statusIcon = const SizedBox.shrink();
                      if (visible) {
                        statusIcon = Icon(
                          Icons.circle,
                          size: 12,
                          color: isOnline ? Colors.green : Colors.grey,
                        );
                      }

                      return Card(
                        color: cardColor,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                                ? NetworkImage(photoUrl)
                                : null,
                            child: (photoUrl == null || photoUrl.isEmpty)
                                ? Text(name[0].toUpperCase(), style: TextStyle(color: textColor))
                                : null,
                          ),
                          title: Text(name, style: TextStyle(color: textColor)),
                          trailing: statusIcon,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  currentUserId: currentUserId,
                                  otherUserId: friendId,
                                  otherUsername: name,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: themeColor,
            onPressed: () => _addFriend(context),
            child: const Icon(Icons.person_add, color: Colors.white),
          ),
        );
      },
    );
  }
}
