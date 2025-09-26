// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';
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
  bool _loading = false;
  bool? _isDarkMode; // ✅ başta null → sistemden alınacak

  Future<void> login() async {
    setState(() => _loading = true);

    try {
      final query = await users.where("username", isEqualTo: username).get();

      if (query.docs.isNotEmpty) {
        final userDoc = query.docs.first;
        final data = userDoc.data();

        final storedHash = data["passwordHash"];
        final valid = BCrypt.checkpw(password, storedHash);

        if (valid) {
          await users.doc(userDoc.id).update({
            "isOnline": true,
            "lastSeen": FieldValue.serverTimestamp(),
          });

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => UserListScreen(currentUserId: userDoc.id),
            ),
          );
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Hatalı kullanıcı adı veya şifre")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Hata: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Eğer _isDarkMode null ise → sistemi oku
    final isDark =
        _isDarkMode ?? MediaQuery.of(context).platformBrightness == Brightness.dark;

    final background = isDark ? Colors.grey[900] : Colors.grey[50];
    final cardColor = isDark ? Colors.grey[850]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: Text("Giriş Yap", style: TextStyle(color: textColor)),
        backgroundColor: cardColor,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: textColor,
            ),
            onPressed: () {
              setState(() {
                _isDarkMode = !isDark; // ✅ sistemi ez, kullanıcı seçsin
              });
            },
          ),
        ],
      ),
      backgroundColor: background,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: "Kullanıcı adı",
                labelStyle: TextStyle(color: textColor),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: textColor.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: textColor),
                ),
              ),
              onChanged: (val) => username = val.trim(),
            ),
            const SizedBox(height: 12),
            TextField(
              style: TextStyle(color: textColor),
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Şifre",
                labelStyle: TextStyle(color: textColor),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: textColor.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: textColor),
                ),
              ),
              onChanged: (val) => password = val.trim(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cardColor,
                foregroundColor: textColor,
              ),
              onPressed: _loading ? null : login,
              child: _loading
                  ? CircularProgressIndicator(color: textColor)
                  : const Text("Giriş Yap"),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              child: Text(
                "Hesabın yok mu? Kayıt ol",
                style: TextStyle(color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
