import 'package:firebase_database/firebase_database.dart';

/// Referensi root ke Firebase Realtime Database proyek `floodly-27cd8`.
final database = FirebaseDatabase.instance.ref();

/// Node utama `/floodly` yang berisi data jarak ultrasonic, ketinggian air, status, dan buzzer.
final floodRef = database.child('floodly');
