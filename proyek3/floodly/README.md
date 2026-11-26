# Floodly (Flutter)

Aplikasi **Flutter** untuk memantau **ketinggian air**, jarak permukaan air ke sensor **Ultrasonic HC-SR04**, status bahaya banjir (`AMAN` / `BAHAYA`), serta status **Buzzer Aktif** dari **ESP32** secara real-time melalui **Firebase Realtime Database (`floodly-27cd8`)**.

---

## 1. Fitur Utama

- **Monitoring Ketinggian Air Real-Time**: menampilkan ketinggian air (`cm`), persentase penuh (`0–100%`), dan *progress bar* dengan warna dinamis (biru saat `AMAN`, merah saat `BAHAYA`).
- **Peringatan Bahaya Otomatis (`<= 5.0 cm`)**: menampilkan badge **`BAHAYA`** dan banner peringatan merah ketika jarak air ke sensor ultrasonic mencapai `<= 5.0 cm` (sejalan dengan alarm buzzer pada ESP32).
- **Metrik Sensor & Buzzer**: menampilkan **Jarak ke Sensor (`cm`)** dan **Status Buzzer (`BUNYI` / `MATI`)** secara langsung dari stream Firebase.
- **Penanganan State Lengkap**: tampilan *loading*, error koneksi dengan tombol **Coba Lagi**, dan kondisi database kosong.

---

## 2. Penjelasan Package yang Dipakai

Daftar package berikut diambil dari [`pubspec.yaml`](./pubspec.yaml) (Dart SDK `^3.9.2`):

### Dependencies (Runtime)
| Package | Versi | Fungsi dalam Proyek |
| :--- | :---: | :--- |
| `flutter` | SDK | Framework utama untuk membangun tampilan UI Material 3, state management, dan widget. |
| `firebase_core` | `^5.1.0` | Package inti Firebase untuk inisialisasi proyek (`Firebase.initializeApp`) sebelum layanan Firebase lain dipakai. |
| `firebase_database` | `^13.0.1` | Menghubungkan aplikasi ke **Firebase Realtime Database** untuk membaca stream real-time (`onValue`) dari node `/floodly`. |
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
├── main.dart                     # Entry point aplikasi, inisialisasi Firebase, dan konfigurasi tema Material 3
├── firebase_options.dart         # Konfigurasi Firebase per platform (hasil generate FlutterFire CLI)
├── home_page.dart                # Halaman utama dashboard: stream /floodly dan susunan kartu monitoring
├── models/
│   └── flood_data.dart           # Model data FloodData dan parser snapshot Firebase /floodly
├── service/
│   └── flood_db.dart             # Referensi root database dan node /floodly pada Firebase RTDB
└── widgets/
    ├── water_level_card.dart     # Kartu utama ketinggian air (cm & %), progress bar, badge & banner BAHAYA
    ├── metric_tile.dart          # Kartu metrik ringkas (Jarak ke Sensor & Status Buzzer)
    └── status_view.dart          # Tampilan status loading, data kosong, dan error beserta tombol Coba Lagi
```

### Penjelasan Peran Setiap File
1. **`lib/main.dart`**  
   Memanggil `WidgetsFlutterBinding.ensureInitialized()` dan `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` sebelum menjalankan `MyApp` dengan tema Material 3 bernuansa biru air (`#16699A`).
2. **`lib/firebase_options.dart`**  
   File hasil generate **FlutterFire CLI** yang menyimpan kredensial proyek `floodly-27cd8` dan `databaseURL` (`asia-southeast1`) untuk platform **Android**, **Web**, dan **Windows**.
3. **`lib/service/flood_db.dart`**  
   Menyediakan referensi global `database` (`FirebaseDatabase.instance.ref()`) dan `floodRef` (`database.child('floodly')`).
4. **`lib/models/flood_data.dart`**  
   Mendefinisikan class `FloodData` untuk mengubah payload map mentah dari Firebase (`distanceCm`, `waterLevelCm`, `sensorHeightCm`, `dangerThresholdCm`, `percent`, `status`, `buzzer`) menjadi objek Dart dengan helper `isDanger` dan `isBuzzerOn`.
5. **`lib/home_page.dart`**  
   Halaman utama berbasis `StreamBuilder<DatabaseEvent>` yang mendengarkan perubahan `/floodly` secara real-time, menangani state *loading* / *error* / *empty*, dan menyusun kartu monitoring.
6. **`lib/widgets/water_level_card.dart`**  
   Menampilkan angka ketinggian air (`cm`), persentase penuh (`%`), progress bar, badge `AMAN` / `BAHAYA`, serta banner peringatan merah saat jarak air `<= 5.0 cm`.
7. **`lib/widgets/metric_tile.dart`**  
   Komponen kartu informasi reusable untuk menampilkan **Jarak ke Sensor** dan **Status Buzzer**.
8. **`lib/widgets/status_view.dart`**  
   Komponen tampilan pengganti saat aplikasi sedang menghubungkan ke Firebase, node `/floodly` masih kosong, atau terjadi error koneksi.

---

## 4. Struktur Node & Rules Firebase RTDB

```json
{
  "floodly": {
    "distanceCm": 12.5,
    "waterLevelCm": 7.5,
    "sensorHeightCm": 20.0,
    "dangerThresholdCm": 5.0,
    "percent": 38,
    "status": "AMAN",
    "buzzer": "OFF"
  }
}
```

Pastikan Rules di Firebase Console (**Realtime Database → Rules**) proyek `floodly-27cd8` mengizinkan baca/tulis pada `/floodly`:
```json
{
  "rules": {
    "floodly": {
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

4. **Hubungkan proyek Flutter ke Firebase** *(jalankan di dalam folder `proyek3/floodly`)*:
   ```bash
   flutterfire configure
   ```
   Pilih proyek Firebase yang diinginkan serta platform target (misalnya **Android**, **Web**, dan **Windows**). Perintah ini otomatis membuat/memperbarui file `lib/firebase_options.dart` dan file konfigurasi platform seperti `android/app/google-services.json`.

---

## 6. Cara Menjalankan & Pengujian

Jalankan perintah berikut di dalam folder `proyek3/floodly`:

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
