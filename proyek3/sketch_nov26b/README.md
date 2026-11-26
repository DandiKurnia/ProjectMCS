# Floodly ESP32 (Ultrasonic HC-SR04 + Buzzer Aktif + Firebase RTDB)

Program mikrokontroler **ESP32** (`sketch_nov26b.ino`) untuk sistem monitoring **ketinggian air (Floodly)** menggunakan sensor jarak **Ultrasonic HC-SR04** dan alarm **Buzzer Aktif** (otomatis berbunyi saat jarak air ke sensor `<= 5 cm`), terintegrasi secara real-time dengan **Firebase Realtime Database (`floodly-27cd8`)** dan aplikasi **Flutter Floodly** (`proyek3/floodly`).

---

## 1. Perangkat Keras yang Dibutuhkan

- **ESP32 DevKit**
- **Sensor Ultrasonic HC-SR04** *(atau HC-SR04P versi 3.3V)*
- **Buzzer Aktif** (Active Buzzer 3.3V / 5V)
- Resistor `1 kΩ` & `2 kΩ` *(opsional/disarankan sebagai pembagi tegangan pada pin `ECHO` jika HC-SR04 memakai 5V)*
- Kabel jumper & breadboard

---

## 2. Konfigurasi Pin (Wiring)

| Komponen | Pin Modul | Pin ESP32 | Keterangan |
| :--- | :--- | :--- | :--- |
| **Ultrasonic HC-SR04** | `TRIG` | **GPIO5** | Output pulsa trigger 10 µs |
| **Ultrasonic HC-SR04** | `ECHO` | **GPIO18** | Input pulsa echo *(disarankan pembagi tegangan 1kΩ + 2kΩ jika VCC sensor 5V agar tegangan input ke ESP32 aman di ~3.3V)* |
| **Ultrasonic HC-SR04** | `VCC` | **5V / VIN** | Gunakan `3V3` jika memakai versi **HC-SR04P (3.3V)** |
| **Ultrasonic HC-SR04** | `GND` | **GND** | Ground bersama (*common ground*) |
| **Buzzer Aktif** | `+` / `S` | **GPIO19** | Output digital pengendali buzzer (**Active-HIGH**) |
| **Buzzer Aktif** | `-` / `GND` | **GND** | Ground bersama (*common ground*) |

---

## 3. Board & Library Arduino IDE

### Board Package (Boards Manager)
- **esp32** by *Espressif Systems*  
  Sudah termasuk library bawaan:
  - `WiFi.h` — koneksi WiFi ESP32
  - `WiFiClientSecure.h` — koneksi HTTPS/TLS ke server Firebase

### Library Eksternal (Library Manager)
- **FirebaseClient** by *Mobizt*  
  Digunakan untuk mengirim data JSON secara atomik ke Firebase Realtime Database (`#define ENABLE_DATABASE` dan `#include <FirebaseClient.h>`).

*(Pembacaan sensor ultrasonic HC-SR04 dan kontrol buzzer aktif menggunakan fungsi bawaan ESP32 Arduino sehingga tidak memerlukan library tambahan.)*

---

## 4. Konfigurasi Utama di `sketch_nov26b.ino`

Sesuaikan konstanta berikut sebelum *Upload*:

```cpp
// WiFi
#define WIFI_SSID     "A56"
#define WIFI_PASSWORD "12345678"

// Firebase (proyek3/floodly -> floodly-27cd8)
#define API_KEY      "AIzaSyCxNXS0egPsCNju5r0SNYR-zZgJSuE66o8"
#define DATABASE_URL "https://floodly-27cd8-default-rtdb.asia-southeast1.firebasedatabase.app/"
#define DEBUG_FIREBASE false     // ubah ke true untuk melihat detail respons Firebase

// Pin & Mode Buzzer Aktif
#define TRIG_PIN   5
#define ECHO_PIN   18
#define BUZZER_PIN 19
#define BUZZER_ACTIVE_LOW false  // false = Active-HIGH (HIGH=bunyi), true = Active-LOW (LOW=bunyi)

// Parameter Ketinggian Air
const float BATAS_BAHAYA_CM  = 5.0;   // Jarak air <= 5.0 cm -> BAHAYA & Buzzer BUNYI
const float TINGGI_SENSOR_CM = 20.0;  // Tinggi sensor dari dasar wadah (sesuaikan dengan wadah Anda)
```

---

## 5. Cara Kerja & Perhitungan

1. **Pembacaan Sensor (`readIntervalMs = 500 ms`)**:
   - ESP32 membaca **5 sampel** jarak dari HC-SR04 (`readDistanceCm(5)`), mengabaikan sampel timeout/di luar rentang (`2–400 cm`), lalu menghitung rata-ratanya (`distanceCm`).
2. **Perhitungan Ketinggian Air**:
   - `waterLevelCm = TINGGI_SENSOR_CM - distanceCm` (dibatasi `0` sampai `TINGGI_SENSOR_CM`).
   - `percent = (waterLevelCm / TINGGI_SENSOR_CM) * 100` (`0–100%`).
3. **Logika Buzzer Aktif**:
   - Jika `distanceCm <= 5.0 cm` → Status **`BAHAYA`**, **Buzzer BUNYI** (`GPIO19 = HIGH`).
   - Jika `distanceCm > 5.0 cm` → Status **`AMAN`**, **Buzzer MATI** (`GPIO19 = LOW`).
4. **Pengiriman ke Firebase (`firebaseIntervalMs = 2000 ms`)**:
   - Seluruh data dikirim dalam 1 payload JSON ke node `/floodly` tiap **2 detik**, atau **segera** ketika status berubah (`AMAN` ↔ `BAHAYA`) agar notifikasi di aplikasi Flutter langsung muncul.

---

## 6. Struktur Data & Rules Firebase RTDB

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

### Aturan (Rules) Firebase RTDB
Karena program menggunakan `NoAuth`, pastikan Rules di Firebase Console (**Realtime Database → Rules**) proyek `floodly-27cd8` mengizinkan baca/tulis pada `/floodly`:

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

## 7. Cara Upload & Monitoring

1. Buka `sketch_nov26b.ino` di **Arduino IDE**.
2. Pilih Board: **ESP32 Dev Module** dan pilih **Port COM** yang sesuai.
3. Klik **Verify** lalu **Upload**.
4. Buka **Serial Monitor** dengan baud rate **`115200`**.

### Contoh Output Serial Monitor
```text
Connecting WiFi....
WiFi Connected!

=== FLOODLY - MONITOR KETINGGIAN AIR READY ===
Ultrasonic -> TRIG: GPIO5 | ECHO: GPIO18
Buzzer     -> PIN : GPIO19 (Buzzer Aktif - Active-HIGH)
Batas Alarm: Jarak air <= 5.0 cm -> Buzzer BUNYI
Tinggi Sensor: 20.0 cm | Firebase Node: /floodly
------------------------------------------------
Jarak:  12.4 cm | Tinggi Air:   7.6 cm ( 38%) | Status: AMAN   | Buzzer: MATI
Jarak:   4.6 cm | Tinggi Air:  15.4 cm ( 77%) | Status: BAHAYA | Buzzer: BUNYI
```

---

## 8. Troubleshooting Singkat

- **Muncul `[!] Sensor ultrasonic tidak terbaca`**: periksa kabel `VCC`, `GND`, `TRIG (GPIO5)`, `ECHO (GPIO18)`, atau jarak objek terlalu dekat (`< 2 cm`, di bawah batas minimum HC-SR04).
- **Buzzer bunyi terbalik (bunyi saat aman, mati saat bahaya)**: ubah `#define BUZZER_ACTIVE_LOW` dari `false` menjadi `true`.
- **`[Firebase Error - ...]` muncul di Serial Monitor**: periksa koneksi internet WiFi, `DATABASE_URL` (`asia-southeast1`), dan pastikan Rules RTDB pada `/floodly` sudah `.read: true` dan `.write: true`.
