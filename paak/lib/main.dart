import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'services/user_provider.dart';
import 'screens/role_selector_screen.dart';
import 'screens/dosen/dosen_home_screen.dart';
import 'screens/mahasiswa/mahasiswa_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with try-catch
  // If the user hasn't added google-services.json, this will print an error
  // but allow the app to run in "demo mode" safely without crashing.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase failed to initialize: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Presensi BLE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
          primary: Colors.indigo,
          secondary: Colors.teal,
          surface: const Color(0xFF0F172A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const AppHomeRouter(),
    );
  }
}

class AppHomeRouter extends StatelessWidget {
  const AppHomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    // Show a loading screen until SharedPreferences data is loaded
    if (!userProvider.isInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(
                  color: Colors.indigoAccent,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Memuat Profil...",
                style: TextStyle(
                  color: Colors.indigo.shade200,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Direct routing based on stored user profile
    if (userProvider.role == 'dosen') {
      return const DosenHomeScreen();
    } else if (userProvider.role == 'mahasiswa') {
      return const MahasiswaHomeScreen();
    } else {
      return const RoleSelectorScreen();
    }
  }
}
