import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:locker/firebase_options.dart';
import 'package:locker/home_page.dart';

/// Entry point aplikasi Flutter Smart Locker.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Locker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E5B78)),
      ),
      home: const HomePage(),
    );
  }
}
