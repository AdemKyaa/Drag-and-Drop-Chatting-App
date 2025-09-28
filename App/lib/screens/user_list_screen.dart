import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

// --- Diller ---
const Map<String, Map<String, String>> _userListTranslations = {
  'en': {
    'friends': 'Friends',
    'noFriends': 'You haven’t added any friends yet.',
    'addFriend': 'Add Friend',
    'enterUsername': 'Enter username',
    'cancel': 'Cancel',
    'add': 'Add',
    'userNotFound': 'User not found',
  },
  'tr': {
    'friends': 'Arkadaşlar',
    'noFriends': 'Henüz arkadaş eklemediniz.',
    'addFriend': 'Arkadaş Ekle',
    'enterUsername': 'Kullanıcı adını gir',
    'cancel': 'İptal',
    'add': 'Ekle',
    'userNotFound': 'Kullanıcı bulunamadı',
  },
};

String ut(String lang, String key) {
  return _userListTranslations[lang]?[key] ?? key;
}

class UserListScreen extends StatelessWidget {
  final String currentUserId;

  const UserListScreen({super.key, required this.currentUserId});

  // Arkadaş ekleme işlemi
  Future<void> _addFriend(BuildContext context, String lang) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ut(lang, 'addFriend')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: ut(lang, 'enterUsername'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ut(lang, 'cancel')),
          ),
          TextButton(
            onPressed: () async {
              final username = controller.text.trim();
              if (username.isEmpty) return;

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
                  SnackBar(content: Text(ut(lang, 'userNotFound'))),
                );
              }
            },
            child: Text(ut(lang, 'add')),
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
        final String lang = userData["lang"] ?? 'tr'; // 🔹 dil Firestore’dan

        final background = isDarkMode ? Colors.grey[900] : Colors.grey[50];
        final cardColor = isDarkMode ? Colors.black : Colors.white;
        final textColor = isDarkMode ? Colors.white : Colors.black;
        final themeColor = Color(seed);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: cardColor,
            foregroundColor: textColor,
            iconTheme: IconThemeData(color: textColor),
            title: Text(ut(lang, 'friends'), style: TextStyle(color: textColor)),
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
                    ut(lang, 'noFriends'),
                    style: TextStyle(color: textColor),
                  ),
                );
              }

              return ListView.builder(
                itemCount: friends.length,
                itemBuilder: (ctx, i) {
                  final friendId = friends[i].id;

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("users")
                        .doc(friendId)
                        .snapshots(),
                    builder: (ctx, userSnap) {
                      if (!userSnap.hasData) return const SizedBox.shrink();

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
            onPressed: () => _addFriend(context, lang),
            child: const Icon(Icons.person_add, color: Colors.white),
          ),
        );
      },
    );
  }
}
