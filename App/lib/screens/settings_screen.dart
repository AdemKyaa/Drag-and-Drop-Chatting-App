import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

// --- Diller ---
const Map<String, Map<String, String>> _translations = {
  'en': {
    'settings': 'Settings',
    'profileName': 'Profile Name',
    'onlineVisible': 'Show Online Status',
    'darkMode': 'Dark Mode',
  },
  'tr': {
    'settings': 'Ayarlar',
    'profileName': 'Profil Adı',
    'onlineVisible': 'Online Durumunu Göster',
    'darkMode': 'Karanlık Mod',
  },
};

String t(String lang, String key) {
  return _translations[lang]?[key] ?? key;
}

class SettingsScreen extends StatefulWidget {
  final String currentUserId;
  const SettingsScreen({super.key, required this.currentUserId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final picker = ImagePicker();
  late final String uid;

  String _selectedLang = 'tr'; // Varsayılan Türkçe

  @override
  void initState() {
    super.initState();
    uid = widget.currentUserId;
    FirebaseFirestore.instance.collection('users').doc(uid).get().then((snap) {
      final data = snap.data();
      if (data != null) {
        _nameController.text = data['displayName'] ?? "";
        if (data['lang'] != null) {
          setState(() {
            _selectedLang = data['lang'];
          });
        }
      }
    });
  }

  Future<void> _updateProfileName(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'displayName': _nameController.text.trim()},
      SetOptions(merge: true),
    );
  }

  Future<void> _pickPhoto(String uid) async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    final ref = FirebaseStorage.instance.ref().child('profile_photos/$uid.jpg');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'photoUrl': url},
      SetOptions(merge: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.currentUserId;
    const themeColor = Color(0xFF4CAF50); // 🌿 Sabit canlı pastel yeşil

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final photoUrl = data['photoUrl'] as String? ?? "";
        final bool isOnlineVisible = data['isOnlineVisible'] ?? true;
        final bool isDarkMode = data['isDarkMode'] ?? false;

      final background = isDarkMode
          ? const Color(0xFF1B2E24)   // Dark mode background
          : const Color(0xFFB9DFC1);  // Light mode background

      final cardColor = isDarkMode
          ? const Color(0xFF264332)   // Dark mode card
          : const Color(0xFF9CC5A4);  // Light mode card

      final textColor = isDarkMode
          ? const Color(0xFFE6F2E9)   // Dark mode text
          : const Color(0xFF1B3C2E);  // Light mode text

        return Scaffold(
          appBar: AppBar(
            title: Text(t(_selectedLang, 'settings'), style: TextStyle(color: textColor)),
            backgroundColor: cardColor,
            iconTheme: IconThemeData(color: textColor),
          ),
          backgroundColor: background,
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profil Foto
              Center(
                child: GestureDetector(
                  onTap: () => _pickPhoto(uid),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? Icon(Icons.person, size: 40, color: textColor)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Profil Adı
              TextField(
                controller: _nameController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: t(_selectedLang, 'profileName'),
                  labelStyle: TextStyle(color: textColor),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: textColor.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: textColor),
                  ),
                ),
                onSubmitted: (_) => _updateProfileName(uid),
              ),

              const SizedBox(height: 24),

              // Online durum
              SwitchListTile(
                title: Text(t(_selectedLang, 'onlineVisible'),
                    style: TextStyle(color: textColor)),
                activeColor: themeColor,
                value: isOnlineVisible,
                onChanged: (val) async {
                  await FirebaseFirestore.instance.collection('users').doc(uid).set(
                    {'isOnlineVisible': val},
                    SetOptions(merge: true),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Karanlık mod
              SwitchListTile(
                title: Text(t(_selectedLang, 'darkMode'),
                    style: TextStyle(color: textColor)),
                activeColor: themeColor,
                value: isDarkMode,
                onChanged: (val) async {
                  await FirebaseFirestore.instance.collection('users').doc(uid).set(
                    {'isDarkMode': val},
                    SetOptions(merge: true),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Dil seçme (Yazısız, emojiler ortada)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Türk Bayrağı 🇹🇷
                  GestureDetector(
                    onTap: () async {
                      setState(() => _selectedLang = 'tr');
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .set({'lang': 'tr'}, SetOptions(merge: true));
                    },
                    child: Opacity(
                      opacity: _selectedLang == 'tr' ? 1.0 : 0.4,
                      child: const Text("🇹🇷", style: TextStyle(fontSize: 32)),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Amerikan Bayrağı 🇺🇸
                  GestureDetector(
                    onTap: () async {
                      setState(() => _selectedLang = 'en');
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .set({'lang': 'en'}, SetOptions(merge: true));
                    },
                    child: Opacity(
                      opacity: _selectedLang == 'en' ? 1.0 : 0.4,
                      child: const Text("🇺🇸", style: TextStyle(fontSize: 32)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
