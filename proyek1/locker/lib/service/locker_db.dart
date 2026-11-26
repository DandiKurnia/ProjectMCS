import 'package:firebase_database/firebase_database.dart';
import 'package:locker/models/locker_data.dart';

/// Referensi root Firebase Realtime Database (`locker-b9df4`).
final database = FirebaseDatabase.instance.ref();

/// Node utama `/locker` yang menyimpan `status`, `control`, `cards`, dan `logs`.
final lockerRef = database.child('locker');
final lockerControlRef = lockerRef.child('control');
final lockerCardsRef = lockerRef.child('cards');
final lockerLogsRef = lockerRef.child('logs');

/// Mengirim perintah jarak jauh ke ESP32 (`'OPEN'` atau `'CLOSE'`).
Future<void> sendLockerCommand(String command) {
  return lockerControlRef.update({'command': command.toUpperCase()});
}

/// Menambahkan atau memperbarui kartu RFID terdaftar di `/locker/cards/<uidKey>`.
Future<void> saveRfidCard({
  required String uid,
  required String name,
  bool active = true,
}) {
  final key = normalizeUidKey(uid);
  if (key.isEmpty) {
    throw ArgumentError('UID kartu tidak valid.');
  }
  return lockerCardsRef.child(key).set({
    'name': name.trim().isEmpty ? 'Kartu RFID' : name.trim(),
    'active': active,
  });
}

/// Mengaktifkan atau menonaktifkan kartu RFID tanpa menghapusnya.
Future<void> setCardActive(String uidKey, bool active) {
  return lockerCardsRef.child(uidKey).update({'active': active});
}

/// Menghapus kartu RFID dari daftar terdaftar.
Future<void> deleteRfidCard(String uidKey) {
  return lockerCardsRef.child(uidKey).remove();
}

/// Menghapus seluruh riwayat log di `/locker/logs`.
Future<void> clearLockerLogs() {
  return lockerLogsRef.remove();
}
