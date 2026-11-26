import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:floodly/firebase_options.dart';
import 'package:floodly/home_page.dart';

/// Entry point aplikasi Flutter Floodly.
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
      title: 'Floodly',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF16699A)),
      ),
      home: const HomePage(),
    );
  }
}
