import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart'; // 🔒 bcrypt
import 'user_list_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final users = FirebaseFirestore.instance.collection("users");

  String username = "";
  String password = "";

  Future<void> login() async {
    try {
      if (username.trim().isEmpty || password.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Kullanıcı adı ve şifre boş olamaz")),
        );
        return;
      }

      // Kullanıcıyı ada göre bul
      final query = await users.where("username", isEqualTo: username).get();

      if (query.docs.isNotEmpty) {
        final userDoc = query.docs.first;
        final data = userDoc.data();

        // Hash alanı var mı kontrol et
        if (data.containsKey("passwordHash")) {
          final String storedHash = data["passwordHash"];

          // 🔒 Şifre kontrolü
          final bool valid = BCrypt.checkpw(password, storedHash);

          if (valid) {
            // Online durumunu güncelle
            await users.doc(userDoc.id).update({"isOnline": true});

            // ignore: use_build_context_synchronously
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => UserListScreen(currentUserId: userDoc.id),
              ),
            );
            return;
          }
        }
      }

      // Eğer buraya geldiyse giriş başarısız
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Hatalı kullanıcı adı veya şifre")),
      );
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
      appBar: AppBar(title: const Text("Giriş Yap")),
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
              onPressed: login,
              child: const Text("Giriş Yap"),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              child: const Text("Hesabın yok mu? Kayıt ol"),
            ),
          ],
        ),
      ),
    );
  }
}
