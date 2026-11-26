# Smart Garden (Flutter)

Aplikasi **Flutter** untuk memantau kelembapan tanah secara real-time dan mengendalikan pompa air pada **ESP32** dalam mode **Otomatis (`AUTO`)** maupun **Manual (`MANUAL`)** melalui **Firebase Realtime Database**.

---

## 1. Fitur Utama

- **Monitoring Real-Time**: menampilkan persentase kelembapan tanah (`0–100%`), status tanah (`DRY` / `WET`), nilai ADC mentah (`raw`), dan status fisik relay/pompa (`ON` / `OFF`) langsung dari stream Firebase.
- **Kontrol Pompa Otomatis & Manual**:
  - **Otomatis (`AUTO`)**: pompa dikendalikan otomatis oleh ESP32 berdasarkan sensor kelembapan tanah.
  - **Manual (`MANUAL`)**: pengguna dapat menyalakan atau mematikan pompa langsung dari sakelar di aplikasi, lengkap dengan indikator sinkronisasi hingga ESP32 mengonfirmasi status relay fisik.
- **Penanganan State Lengkap**: tampilan *loading*, error koneksi dengan tombol **Coba Lagi**, serta kondisi database kosong.

---

## 2. Penjelasan Package yang Dipakai

Daftar package berikut diambil dari [`pubspec.yaml`](./pubspec.yaml) (Dart SDK `^3.9.2`):

### Dependencies (Runtime)
| Package | Versi | Fungsi dalam Proyek |
| :--- | :---: | :--- |
| `flutter` | SDK | Framework utama untuk membangun tampilan UI (Material 3), state management, dan widget. |
| `firebase_core` | `^5.1.0` | Package inti Firebase untuk inisialisasi proyek (`Firebase.initializeApp`) sebelum layanan Firebase lain digunakan. |
| `firebase_database` | `^13.0.1` | Menghubungkan aplikasi ke **Firebase Realtime Database** untuk membaca stream (`onValue`) dari `/monitoring` dan mengirim perintah kontrol (`update`) ke `/monitoring/control`. |
| `cupertino_icons` | `^1.0.8` | Kumpulan ikon bergaya iOS/Cupertino bawaan template Flutter. |

### Dev Dependencies (Pengembangan & Pengujian)
| Package | Versi | Fungsi dalam Proyek |
| :--- | :---: | :--- |
| `flutter_test` | SDK | Framework pengujian untuk menjalankan unit test dan widget test di folder `test/`. |
| `flutter_lints` | `^5.0.0` | Kumpulan aturan analisis statis (`analysis_options.yaml`) agar kode Dart tetap rapi dan mengikuti praktik terbaik Flutter. |

---

## 3. Struktur File `lib/`

```text
lib/
├── main.dart                     # Entry point aplikasi, inisialisasi Firebase, dan konfigurasi tema Material 3
├── firebase_options.dart         # Konfigurasi Firebase per platform (hasil generate FlutterFire CLI)
├── home_page.dart                # Halaman utama dashboard: stream RTDB, state kontrol, dan susunan kartu UI
├── models/
│   └── monitoring_data.dart      # Model data MonitoringData, enum PumpMode, dan parser snapshot Firebase
├── service/
│   └── realtime_db.dart          # Referensi node RTDB (/monitoring, /monitoring/control) & fungsi tulis kontrol
└── widgets/
    ├── moisture_card.dart        # Kartu utama persentase kelembapan tanah, badge status, dan progress bar
    ├── pump_control_card.dart    # Kartu kontrol mode Otomatis/Manual dan sakelar pompa manual
    ├── info_tile.dart            # Kartu metrik ringkas (Status Pompa/Relay dan Nilai Sensor Raw)
    └── status_view.dart          # Tampilan status loading, data kosong, dan error beserta tombol Coba Lagi
```

### Penjelasan Peran Setiap File
1. **`lib/main.dart`**  
   Memanggil `WidgetsFlutterBinding.ensureInitialized()` dan `Firebase.initializeApp(...)` sebelum menjalankan widget root `MyApp` dengan tema Material 3 bernuansa hijau (`#2E7D52`).
2. **`lib/firebase_options.dart`**  
   File hasil generate **FlutterFire CLI** yang menyimpan kredensial dan `databaseURL` Firebase untuk platform **Android**, **Web**, dan **Windows**.
3. **`lib/service/realtime_db.dart`**  
   Menyediakan referensi global `monitoringRef` (`/monitoring`) dan `controlRef` (`/monitoring/control`), serta fungsi `setPumpMode()` dan `setManualPump()` untuk memperbarui perintah pompa ke Firebase.
4. **`lib/models/monitoring_data.dart`**  
   Mendefinisikan enum `PumpMode` (`auto`, `manual`) dan class `MonitoringData` yang mengubah payload map mentah dari Firebase (`soil`, `relay`, `control`) menjadi objek Dart yang aman dari perbedaan tipe data (angka/string/boolean).
5. **`lib/home_page.dart`**  
   Halaman utama berbasis `StreamBuilder<DatabaseEvent>` yang mendengarkan perubahan `/monitoring` secara real-time, mengelola status proses penyimpanan kontrol (`_isUpdatingControl`), dan menampilkan `SnackBar` jika terjadi gagal tulis ke Firebase.
6. **`lib/widgets/moisture_card.dart`**  
   Menampilkan angka kelembapan tanah (`%`), badge kondisi tanah (`Tanah Kering (DRY)` / `Tanah Basah (WET)`), dan `LinearProgressIndicator` dengan warna dinamis.
7. **`lib/widgets/pump_control_card.dart`**  
   Menampilkan `SegmentedButton` untuk berpindah antara **Otomatis** dan **Manual**. Pada mode Otomatis ditampilkan informasi kerja sensor; pada mode Manual ditampilkan `Switch` ON/OFF pompa beserta status sinkronisasi dengan ESP32.
8. **`lib/widgets/info_tile.dart`**  
   Komponen kartu informasi reusable untuk menampilkan **Status Pompa / Relay** dan **Nilai Sensor (Raw)**.
9. **`lib/widgets/status_view.dart`**  
   Komponen tampilan pengganti saat aplikasi masih menghubungkan ke Firebase, node `/monitoring` masih kosong, atau terjadi error pembacaan database.

---

## 4. Struktur Node Firebase yang Digunakan

Aplikasi membaca satu node utama `/monitoring` dan menulis perintah kontrol ke `/monitoring/control`:

```json
{
  "monitoring": {
    "soil": {
      "raw": 1994,
      "moisture": 73,
      "status": "WET"
    },
    "relay": {
      "status": "OFF"
    },
    "control": {
      "mode": "AUTO",
      "pump": "OFF"
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

4. **Hubungkan proyek Flutter ke Firebase** *(jalankan di dalam folder `proyek2/smartgarden`)*:
   ```bash
   flutterfire configure
   ```
   Pilih proyek Firebase yang diinginkan serta platform target (misalnya **Android**, **Web**, dan **Windows**). Perintah ini otomatis membuat/memperbarui file `lib/firebase_options.dart` dan file konfigurasi platform seperti `android/app/google-services.json`.

---

## 6. Cara Menjalankan & Pengujian

Jalankan perintah berikut di dalam folder `proyek2/smartgarden`:

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
