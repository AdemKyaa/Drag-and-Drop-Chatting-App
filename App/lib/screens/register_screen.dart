import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';
import 'user_list_screen.dart';

// --- Diller ---
const Map<String, Map<String, String>> _registerTranslations = {
  'en': {
    'register': 'Register',
    'username': 'Username',
    'password': 'Password',
    'registerBtn': 'Register',
    'emptyError': '⚠️ Username and password cannot be empty',
    'existsError': '⚠️ This username is already taken',
    'error': '❌ Registration error',
  },
  'tr': {
    'register': 'Kayıt Ol',
    'username': 'Kullanıcı adı',
    'password': 'Şifre',
    'registerBtn': 'Kayıt Ol',
    'emptyError': '⚠️ Kullanıcı adı ve şifre boş olamaz',
    'existsError': '⚠️ Bu kullanıcı adı zaten alınmış',
    'error': '❌ Kayıt hatası',
  },
};

String rt(String lang, String key) {
  return _registerTranslations[lang]?[key] ?? key;
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  bool? _isDarkMode;
  String _selectedLang = 'tr'; // 🔹 varsayılan TR

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(rt(_selectedLang, 'emptyError'))),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (existing.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(rt(_selectedLang, 'existsError'))),
        );
        return;
      }

      final uid = FirebaseFirestore.instance.collection('users').doc().id;
      final hashed = BCrypt.hashpw(password, BCrypt.gensalt());

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'username': username,
        'passwordHash': hashed,
        'displayName': username,
        'photoUrl': '',
        'isOnline': true,
        'isOnlineVisible': true,
        'themeColor': 0xFF2962FF,
        'chatBgType': 'color',
        'chatBgColor': 0xFFFFFFFF,
        'chatBgUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
        'lang': _selectedLang, // 🔹 seçilen dili kaydet
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => UserListScreen(currentUserId: uid)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${rt(_selectedLang, 'error')}: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkMode ??
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    final background = isDark ? Colors.grey[900] : Colors.grey[50];
    final cardColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: Text(rt(_selectedLang, 'register')),
        backgroundColor: cardColor,
        foregroundColor: textColor,
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

          // 🔹 Tema butonu
          IconButton(
            icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            color: textColor,
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
              controller: _usernameController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: rt(_selectedLang, 'username'),
                labelStyle: TextStyle(color: textColor),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: textColor.withOpacity(0.6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: textColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: rt(_selectedLang, 'password'),
                labelStyle: TextStyle(color: textColor),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: textColor.withOpacity(0.6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: textColor),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cardColor,
                      foregroundColor: textColor,
                    ),
                    onPressed: _register,
                    child: Text(rt(_selectedLang, 'registerBtn')),
                  ),
          ],
        ),
      ),
    );
  }
}
