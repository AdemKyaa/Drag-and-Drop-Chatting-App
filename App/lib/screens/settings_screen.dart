import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

const _presetSeeds = <int>[
  0xFF2962FF, // Mavi
  0xFF00C853, // Yeşil
  0xFFFF1744, // Kırmızı
  0xFFFF6D00, // Turuncu
  0xFFAA00FF, // Mor
  0xFF00B0FF, // Açık mavi
];

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

  @override
  void initState() {
    super.initState();
    uid = widget.currentUserId;
    FirebaseFirestore.instance.collection('users').doc(uid).get().then((snap) {
      final data = snap.data();
      if (data != null) {
        _nameController.text = data['displayName'] ?? "";
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final photoUrl = data['photoUrl'] as String? ?? "";
        final int? currentSeed = data['themeColor'] as int?;
        final bool isOnlineVisible = data['isOnlineVisible'] ?? true;
        final bool isDarkMode = data['isDarkMode'] ?? false;

        final background = isDarkMode ? Colors.grey[900] : Colors.grey[50];
        final cardColor = isDarkMode ? Colors.black : Colors.white;
        final textColor = isDarkMode ? Colors.white : Colors.black;

        return Scaffold(
          appBar: AppBar(
            title: Text("Ayarlar", style: TextStyle(color: textColor)),
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
                  labelText: "Profil Adı",
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
              Text("Tema Rengi",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _presetSeeds.map((seed) {
                  final selected = currentSeed == seed;
                  return InkWell(
                    onTap: () async {
                      await FirebaseFirestore.instance.collection('users').doc(uid).set(
                        {'themeColor': seed},
                        SetOptions(merge: true),
                      );
                    },
                    child: CircleAvatar(
                      backgroundColor: Color(seed),
                      child: selected ? const Icon(Icons.check, color: Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              SwitchListTile(
                title: Text("Online Durumunu Göster", style: TextStyle(color: textColor)),
                activeColor: Colors.blue,
                value: isOnlineVisible,
                onChanged: (val) async {
                  await FirebaseFirestore.instance.collection('users').doc(uid).set(
                    {'isOnlineVisible': val},
                    SetOptions(merge: true),
                  );
                },
              ),

              const SizedBox(height: 24),
              SwitchListTile(
                title: Text("Karanlık Mod", style: TextStyle(color: textColor)),
                activeColor: Colors.blue,
                value: isDarkMode,
                onChanged: (val) async {
                  await FirebaseFirestore.instance.collection('users').doc(uid).set(
                    {'isDarkMode': val},
                    SetOptions(merge: true),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
