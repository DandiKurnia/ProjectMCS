# Smart Locker (Flutter)

Aplikasi **Flutter** untuk memantau status loker secara real-time, membuka/mengunci loker jarak jauh, mengelola daftar kartu **RFID RC522** yang diizinkan, serta melihat riwayat aktivitas dari **ESP32** melalui **Firebase Realtime Database (`locker-b9df4`)**.

---

## 1. Fitur Utama

- **Status Loker Real-Time**: menampilkan kondisi loker (**Terkunci** / **Terbuka**) dan sumber aksi terakhir (`Kartu RFID`, `Aplikasi`, `Auto-Lock`, atau `Sistem`).
- **Kontrol Jarak Jauh**: tombol **Buka Loker** (`OPEN`) dan **Kunci** (`CLOSE`) dengan indikator status sinkronisasi saat perintah sedang menunggu eksekusi ESP32.
- **Tap RFID Terakhir & Daftar Cepat**: menampilkan UID kartu terakhir yang di-tap pada ESP32 beserta statusnya (`Diterima` / `Ditolak`). Jika UID belum terdaftar, tersedia tombol 1 klik **Daftarkan UID Ini**.
- **Manajemen Kartu RFID (`/locker/cards`)**: tambah kartu baru (input manual atau dari tap terakhir), aktifkan/nonaktifkan kartu lewat `Switch`, dan hapus kartu dengan dialog konfirmasi.
- **Riwayat Aktivitas (`/locker/logs`)**: daftar 15 aktivitas terbaru (buka, kunci, akses ditolak) lengkap dengan nama kartu, UID, sumber aksi, dan waktu lokal, serta tombol **Hapus Log**.

---

## 2. Penjelasan Package yang Dipakai

Daftar package berikut diambil dari [`pubspec.yaml`](./pubspec.yaml) (Dart SDK `^3.9.2`):

### Dependencies (Runtime)
| Package | Versi | Fungsi dalam Proyek |
| :--- | :---: | :--- |
| `flutter` | SDK | Framework utama untuk membangun UI Material 3, state management, dialog, dan widget. |
| `firebase_core` | `^5.1.0` | Package inti Firebase untuk inisialisasi proyek (`Firebase.initializeApp`) sebelum memakai layanan Firebase lain. |
| `firebase_database` | `^13.0.1` | Menghubungkan aplikasi ke **Firebase Realtime Database** untuk stream real-time (`/locker`) serta operasi tulis/hapus pada `/locker/control`, `/locker/cards`, dan `/locker/logs`. |
| `cupertino_icons` | `^1.0.8` | Kumpulan ikon bergaya iOS/Cupertino bawaan template Flutter. |

### Dev Dependencies (Pengembangan & Pengujian)
| Package | Versi | Fungsi dalam Proyek |
| :--- | :---: | :--- |
| `flutter_test` | SDK | Framework pengujian untuk menjalankan unit test dan widget test di folder `test/`. |
| `flutter_lints` | `^5.0.0` | Aturan analisis statis (`analysis_options.yaml`) agar kode Dart tetap rapi dan bebas peringatan lint. |

---

## 3. Struktur File `lib/`

```text
lib/
├── main.dart                         # Entry point aplikasi, inisialisasi Firebase, dan tema Material 3
├── firebase_options.dart             # Konfigurasi Firebase per platform (hasil generate FlutterFire CLI)
├── home_page.dart                    # Halaman utama dashboard: stream /locker, dialog tambah/hapus kartu, dan aksi kontrol
├── models/
│   └── locker_data.dart              # Model LockerData, LockerStatus, RfidCard, LockerLog, & utilitas normalisasi UID
├── service/
│   └── locker_db.dart                # Referensi node RTDB (/locker/*) & fungsi kirim perintah, kelola kartu, dan hapus log
└── widgets/
    ├── locker_status_card.dart       # Kartu status loker, tombol Buka/Kunci, info tap RFID terakhir, & tombol daftar cepat
    ├── cards_section.dart            # Kartu daftar RFID terdaftar (Switch aktif/nonaktif, tambah, hapus)
    └── logs_section.dart             # Kartu riwayat aktivitas terbaru beserta tombol hapus log
```

### Penjelasan Peran Setiap File
1. **`lib/main.dart`**  
   Memanggil `WidgetsFlutterBinding.ensureInitialized()` dan `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` sebelum menjalankan `MyApp` dengan tema Material 3 (`#1E5B78`).
2. **`lib/firebase_options.dart`**  
   File hasil generate **FlutterFire CLI** yang berisi kredensial proyek `locker-b9df4` dan `databaseURL` untuk platform **Android**, **Web**, dan **Windows**.
3. **`lib/models/locker_data.dart`**  
   Mem-parsing snapshot `/locker` menjadi model Dart (`LockerData`, `LockerStatus`, `RfidCard`, `LockerLog`) serta menyediakan fungsi `normalizeUidKey()` (`AA:BB:CC:DD` → `AA-BB-CC-DD`) dan `formatUidDisplay()` (`AA-BB-CC-DD` → `AA:BB:CC:DD`).
4. **`lib/service/locker_db.dart`**  
   Menyediakan referensi `lockerRef`, `lockerControlRef`, `lockerCardsRef`, `lockerLogsRef`, serta fungsi `sendLockerCommand()`, `saveRfidCard()`, `setCardActive()`, `deleteRfidCard()`, dan `clearLockerLogs()`.
5. **`lib/home_page.dart`**  
   Menggunakan `StreamBuilder<DatabaseEvent>` pada `lockerRef.onValue`, mengelola dialog **Tambah Kartu RFID** dan konfirmasi **Hapus Kartu**, serta menampilkan `SnackBar` bila terjadi error saat menulis ke Firebase.
6. **`lib/widgets/locker_status_card.dart`**  
   Menampilkan status loker, indikator perintah tertunda (`OPEN`/`CLOSE`), tombol **Buka Loker** & **Kunci**, serta info **Tap RFID Terakhir** dengan tombol **Daftarkan UID Ini**.
7. **`lib/widgets/cards_section.dart`**  
   Menampilkan daftar kartu terdaftar beserta `Switch` untuk mengaktifkan/menonaktifkan kartu tanpa menghapusnya.
8. **`lib/widgets/logs_section.dart`**  
   Menampilkan 15 riwayat aktivitas terbaru yang diurutkan dari waktu paling baru beserta label aksi (`Loker Dibuka`, `Loker Dikunci`, `Akses Ditolak`).

---

## 4. Struktur Node & Rules Firebase RTDB

```json
{
  "locker": {
    "status": {
      "state": "LOCKED",
      "source": "RFID",
      "lastUid": "AA:BB:CC:DD",
      "lastAccess": "GRANTED"
    },
    "control": {
      "command": "NONE"
    },
    "cards": {
      "AA-BB-CC-DD": {
        "name": "Kartu Utama",
        "active": true
      }
    },
    "logs": {
      "<pushId>": {
        "uid": "AA:BB:CC:DD",
        "cardName": "Kartu Utama",
        "action": "UNLOCK",
        "source": "RFID",
        "timestamp": 1732610000000
      }
    }
  }
}
```

Pastikan Rules di Firebase Console (**Realtime Database → Rules**) mengizinkan akses pada `/locker`:
```json
{
  "rules": {
    "locker": {
      ".read": true,
      ".write": true
    }
  }
}
```

---

## 5. Setup Firebase (Firebase CLI & FlutterFire CLI)

Jika ingin menghubungkan proyek Flutter ke proyek Firebase milik sendiri (atau melakukan konfigurasi ulang `lib/firebase_options.dart`), jalankan langkah berikut:

1. **Install Firebase CLI** *(jika belum terpasang, membutuhkan Node.js)*:
   ```bash
   npm install -g firebase-tools
   ```

2. **Login ke akun Google/Firebase**:
   ```bash
   firebase login
   ```

3. **Aktifkan FlutterFire CLI secara global**:
   ```bash
   dart pub global activate flutterfire_cli
   ```
   > **Catatan (Windows):** Jika perintah `flutterfire` belum dikenali di terminal, pastikan direktori `%LOCALAPPDATA%\Pub\Cache\bin` sudah ditambahkan ke Environment Variable `PATH`, lalu buka ulang terminal.

4. **Hubungkan proyek Flutter ke Firebase** *(jalankan di dalam folder `proyek1/locker`)*:
   ```bash
   flutterfire configure
   ```
   Pilih proyek Firebase yang diinginkan serta platform target (misalnya **Android**, **Web**, dan **Windows**). Perintah ini otomatis membuat/memperbarui file `lib/firebase_options.dart` dan file konfigurasi platform seperti `android/app/google-services.json`.

---

## 6. Cara Menjalankan & Pengujian

Jalankan perintah berikut di dalam folder `proyek1/locker`:

```bash
# 1. Unduh semua dependency
flutter pub get

# 2. Jalankan aplikasi (Android / Web / Windows)
flutter run

# 3. Analisis statis (lint)
flutter analyze

# 4. Jalankan unit & widget test
flutter test
```
