import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';
import 'user_list_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  /// Kullanıcının seçtiği tema (null → sistem temasını kullan)
  bool? _isDarkMode;

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Kullanıcı adı ve şifre boş olamaz")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // Kullanıcı adı zaten var mı kontrol et
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (existing.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Bu kullanıcı adı zaten alınmış")),
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
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => UserListScreen(currentUserId: uid)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Kayıt hatası: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 📱 Eğer kullanıcı override etmemişse cihazın sistem temasını kullan
    final isDark = _isDarkMode ??
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    final background = isDark ? Colors.grey[900] : Colors.grey[50];
    final cardColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kayıt Ol"),
        backgroundColor: cardColor,
        foregroundColor: textColor,
        actions: [
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
                labelText: "Kullanıcı adı",
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
                labelText: "Şifre",
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
                    child: const Text("Kayıt Ol"),
                  ),
          ],
        ),
      ),
    );
  }
}
