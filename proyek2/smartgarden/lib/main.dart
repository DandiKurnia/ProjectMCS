import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:smartgarden/firebase_options.dart';
import 'package:smartgarden/home_page.dart';

/// Titik masuk utama aplikasi Flutter Smart Garden.
void main() async {
  // Pastikan binding engine Flutter siap sebelum memanggil plugin async (Firebase).
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase sesuai platform aktif (Android, Web, atau Windows).
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

/// Widget root aplikasi yang mengatur konfigurasi MaterialApp dan tema.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
      // Gunakan tema Material 3 dengan warna dasar hijau taman.
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D52)),
      ),
    );
  }
}
