import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart'; // 🔒 bcrypt eklendi

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final users = FirebaseFirestore.instance.collection("users");

  String username = "";
  String password = "";

  Future<void> register() async {
    try {
      // Kullanıcı adı boş mu?
      if (username.trim().isEmpty || password.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Kullanıcı adı ve şifre boş olamaz")),
        );
        return;
      }

      // Kullanıcı adı zaten var mı?
      final existing = await users.where("username", isEqualTo: username).get();
      if (existing.docs.isNotEmpty) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Bu kullanıcı adı zaten alınmış")),
        );
        return;
      }

      // 🔒 Parolayı bcrypt ile hashle
      final String passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());

      // Firestore'a kaydet
      await users.add({
        "username": username,
        "passwordHash": passwordHash, // plain text yerine hash saklanıyor
        "createdAt": FieldValue.serverTimestamp(),
        "isOnline": false,
        "hasNewMessage": false,
      });

      // Başarı mesajı
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Kayıt başarılı, şimdi giriş yapabilirsiniz")),
      );

      // Login sayfasına dön
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Hata: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kayıt Ol")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: "Kullanıcı adı"),
              onChanged: (val) => username = val.trim(),
            ),
            TextField(
              decoration: const InputDecoration(labelText: "Şifre"),
              obscureText: true,
              onChanged: (val) => password = val.trim(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: register,
              child: const Text("Kayıt Ol"),
            ),
          ],
        ),
      ),
    );
  }
}
