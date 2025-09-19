// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';

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
      final existing = await users.where("username", isEqualTo: username).get();
      if (existing.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Bu kullanıcı adı zaten alınmış")),
        );
        return;
      }

      final salt = BCrypt.gensalt();
      final passwordHash = BCrypt.hashpw(password, salt);

      await users.add({
        "username": username,
        "passwordHash": passwordHash,
        "createdAt": FieldValue.serverTimestamp(),
        "isOnline": false,
        "hasNewMessage": false,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Kayıt başarılı, şimdi giriş yapabilirsiniz")),
      );
      Navigator.pop(context);
    } catch (e) {
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
              onChanged: (val) => username = val,
            ),
            TextField(
              decoration: const InputDecoration(labelText: "Şifre"),
              obscureText: true,
              onChanged: (val) => password = val,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: register, child: const Text("Kayıt Ol")),
          ],
        ),
      ),
    );
  }
}
