import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/login_screen.dart';
import 'screens/user_list_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: LoginScreen(),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() ?? {};

            // Firestore’dan gelen ayarlar
            final int seed = (data['themeColor'] as int?) ?? 0xFF2962FF;
            final bool isDark = data['isDarkMode'] ?? false;

            // Tema renkleri
            final lightScheme = ColorScheme.fromSeed(
              seedColor: Color(seed),
              brightness: Brightness.light,
            );

            final darkScheme = ColorScheme.fromSeed(
              seedColor: Color(seed),
              brightness: Brightness.dark,
            );

            return MaterialApp(
              debugShowCheckedModeBanner: false,
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,

              // 🔹 Light tema (beyaz tonları)
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: lightScheme,
                scaffoldBackgroundColor: Colors.grey[50],
                appBarTheme: AppBarTheme(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                ),
              ),

              // 🔹 Dark tema (siyah tonları)
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: darkScheme,
                scaffoldBackgroundColor: Colors.grey[900],
                appBarTheme: AppBarTheme(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),

              routes: {
                '/settings': (context) {
                  final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
                  return SettingsScreen(currentUserId: uid);
                },
              },

              home: UserListScreen(currentUserId: user.uid),
            );
          },
        );
      },
    );
  }
}
