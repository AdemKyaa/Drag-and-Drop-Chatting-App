// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'user_list_screen.dart';
import 'register_screen.dart';

// --- Diller ---
const Map<String, Map<String, String>> _loginTranslations = {
  'en': {
    'login': 'Login',
    'username': 'Username',
    'password': 'Password',
    'loginBtn': 'Login',
    'noAccount': 'Don’t have an account? Register',
    'invalid': '❌ Invalid username or password',
    'error': '❌ Error',
  },
  'tr': {
    'login': 'Giriş Yap',
    'username': 'Kullanıcı adı',
    'password': 'Şifre',
    'loginBtn': 'Giriş Yap',
    'noAccount': 'Hesabın yok mu? Kayıt ol',
    'invalid': '❌ Hatalı kullanıcı adı veya şifre',
    'error': '❌ Hata',
  },
};

String lt(String lang, String key) {
  return _loginTranslations[lang]?[key] ?? key;
}

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
  bool? _isDarkMode;
  String _selectedLang = 'tr'; // 🔹 varsayılan TR

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
          // 🔹 FCM token al
          final fcmToken = await FirebaseMessaging.instance.getToken();

          await users.doc(userDoc.id).update({
            "isOnline": true,
            "lastSeen": FieldValue.serverTimestamp(),
            if (fcmToken != null) "fcmToken": fcmToken, // ✅ token kaydı
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
        SnackBar(content: Text(lt(_selectedLang, 'invalid'))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${lt(_selectedLang, 'error')}: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        _isDarkMode ?? MediaQuery.of(context).platformBrightness == Brightness.dark;

    // ✅ Chat ekranıyla uyumlu pastel/koyu yeşil tonları
    final background = isDark
        ? const Color(0xFF1B2E24) // Dark mode background
        : const Color(0xFFB9DFC1); // Light mode background

    final cardColor = isDark
        ? const Color(0xFF264332) // Dark mode card
        : const Color(0xFF9CC5A4); // Light mode card

    final textColor = isDark
        ? const Color(0xFFE6F2E9) // Dark mode text
        : const Color(0xFF1B3C2E); // Light mode text

    return Scaffold(
      appBar: AppBar(
        title: Text(lt(_selectedLang, 'login'), style: TextStyle(color: textColor)),
        backgroundColor: cardColor,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          // 🔹 Dil seçim bayrakları
          GestureDetector(
            onTap: () => setState(() => _selectedLang = 'tr'),
            child: Opacity(
              opacity: _selectedLang == 'tr' ? 1.0 : 0.4,
              child: const Text("🇹🇷", style: TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _selectedLang = 'en'),
            child: Opacity(
              opacity: _selectedLang == 'en' ? 1.0 : 0.4,
              child: const Text("🇺🇸", style: TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),

          // 🔹 Karanlık / aydınlık tema
          IconButton(
            icon: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: textColor,
            ),
            onPressed: () {
              setState(() {
                _isDarkMode = !isDark;
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
                labelText: lt(_selectedLang, 'username'),
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
                labelText: lt(_selectedLang, 'password'),
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
                  : Text(lt(_selectedLang, 'loginBtn')),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              child: Text(
                lt(_selectedLang, 'noAccount'),
                style: TextStyle(color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
