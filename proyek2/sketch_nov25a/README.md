# Smart Garden ESP32 (Firebase Realtime Database)

Program mikrokontroler **ESP32** (`sketch_nov25a.ino`) untuk memantau kelembapan tanah secara real-time dan mengendalikan pompa air melalui modul relay dalam dua mode: **Otomatis (`AUTO`)** dan **Manual (`MANUAL`)**, terintegrasi dengan **Firebase Realtime Database** dan aplikasi **Flutter Smart Garden**.

---

## 1. Perangkat Keras yang Dibutuhkan

- **ESP32 DevKit** (mendukung WiFi & ADC 12-bit)
- **Sensor Kelembapan Tanah (Soil Moisture Sensor)** dengan output analog (`AO`)
- **Modul Relay 1 Channel (Active-HIGH)**
- **Pompa Air** + catu daya eksternal pompa (sesuai tegangan pompa)
- Kabel jumper & breadboard

---

## 2. Konfigurasi Pin (Wiring)

| Komponen | Pin Modul | Pin ESP32 | Keterangan |
| :--- | :--- | :--- | :--- |
| **Sensor Tanah** | `AO` (Analog Out) | **GPIO34** | Input ADC1 (12-bit, atenuasi 11 dB / 0–3.3V). Aman digunakan bersamaan dengan WiFi. |
| **Sensor Tanah** | `VCC` | `3V3` | Disarankan 3.3V agar tegangan output analog aman untuk pin ADC ESP32. |
| **Sensor Tanah** | `GND` | `GND` | Ground bersama (*common ground*). |
| **Modul Relay** | `IN` / `SIG` | **GPIO5** | Output digital pengendali relay (**Active-HIGH**). |
| **Modul Relay** | `VCC` | `5V` / `VIN` (atau `3V3`) | Sesuaikan dengan tegangan kerja modul relay (umumnya 5V). |
| **Modul Relay** | `GND` | `GND` | Ground bersama (*common ground*). |

### Koneksi Pompa ke Terminal Relay (Active-HIGH)
Pada program, `#define RELAY_ACTIVE_LOW false` (**Active-HIGH**):
- **`GPIO5 = HIGH` → Relay ON** (kontak **COM – NO** terhubung → pompa **menyala**)
- **`GPIO5 = LOW` → Relay OFF** (kontak **COM – NO** terbuka → pompa **mati**)

Hubungkan jalur positif catu daya pompa melalui terminal **`COM`** dan **`NO` (Normally Open)** pada relay. Saat ESP32 baru menyala (`setup()`), `GPIO5` langsung diset ke `LOW` agar pompa tetap mati sampai kondisi kontrol terbaca.

> **Catatan Pin Sensor:** Jangan memindahkan pin `AO` ke pin **ADC2** (seperti GPIO15, GPIO2, GPIO4, dll.) karena ADC2 tidak dapat dipakai saat WiFi ESP32 aktif. Jika nilai raw terbaca `< 600` terus-menerus, periksa kembali kabel `AO` pada **GPIO34**.

---

## 3. Board & Library Arduino IDE

### Board Package (Boards Manager)
- **esp32** by *Espressif Systems*
  - Sudah termasuk library bawaan:
    - `WiFi.h` — koneksi WiFi ESP32
    - `WiFiClientSecure.h` — koneksi HTTPS/TLS ke server Firebase

### Library Eksternal (Library Manager)
- **FirebaseClient** by *Mobizt*
  - Digunakan untuk komunikasi ke Firebase Realtime Database (`#define ENABLE_DATABASE` dan `#include <FirebaseClient.h>`).

---

## 4. Konfigurasi di Dalam `sketch_nov25a.ino`

Sesuaikan konstanta berikut sebelum *Upload*:

```cpp
// WiFi
#define WIFI_SSID "A56"
#define WIFI_PASSWORD "12345678"

// Firebase
#define API_KEY "API_KEY_FIREBASE_ANDA"
#define DATABASE_URL "https://firepump-6455a-default-rtdb.asia-southeast1.firebasedatabase.app/"

// Pin & Mode Relay
#define RELAY_PIN 5
#define SOIL_PIN 34
#define RELAY_ACTIVE_LOW false   // false = Active-HIGH, true = Active-LOW
#define DEBUG_FIREBASE false     // ubah ke true untuk melihat log GET/OK Firebase
```

---

## 5. Kalibrasi Sensor & Interval Kerja

| Konstanta | Nilai Default | Fungsi |
| :--- | :---: | :--- |
| `BATAS_KERING` | `2500` | Ambang batas mode `AUTO`: `raw > 2500` = `DRY` (Relay ON), `raw <= 2500` = `WET` (Relay OFF). |
| `DRY_VALUE` | `3600` | Nilai ADC saat tanah sangat kering (dipetakan ke `0%`). |
| `WET_VALUE` | `1400` | Nilai ADC saat tanah sangat basah (dipetakan ke `100%`). |
| `readSoilRaw(10)` | `10 sampel` | Membaca ADC 10 kali dengan jeda 10 ms lalu mengambil nilai rata-rata agar lebih stabil. |
| `controlInterval` | `2000 ms` | Interval ESP32 mengecek mode (`AUTO`/`MANUAL`) dan perintah pompa dari Firebase (tiap 2 detik). |
| `sensorInterval` | `5000 ms` | Interval ESP32 membaca sensor tanah dan mengirim data monitoring ke Firebase (tiap 5 detik). |

---

## 6. Struktur Data Firebase Realtime Database

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

### Penjelasan Node & Alur Kontrol
- **`/monitoring/soil/*`** *(ditulis oleh ESP32)*: nilai ADC mentah (`raw`), persentase kelembapan (`moisture` 0–100), dan status tanah (`"DRY"` / `"WET"`).
- **`/monitoring/relay/status`** *(ditulis oleh ESP32)*: status fisik relay aktual (`"ON"` / `"OFF"`).
- **`/monitoring/control/mode`** *(ditulis oleh Flutter, dibaca oleh ESP32)*:
  - `"AUTO"` — pompa dikendalikan otomatis oleh ESP32 berdasarkan `BATAS_KERING`.
  - `"MANUAL"` — pompa dikendalikan langsung mengikuti `/monitoring/control/pump`.
- **`/monitoring/control/pump`** *(ditulis oleh Flutter, dibaca oleh ESP32)*:
  - `"ON"` / `"OFF"` — perintah nyala/mati pompa saat mode `"MANUAL"`.
- Saat pertama kali terhubung ke Firebase, ESP32 membaca `/monitoring/control` **lebih dulu** sebelum mengevaluasi sensor. Jika node `/monitoring/control` belum ada di RTDB, ESP32 akan mengisi nilai default `mode = "AUTO"` dan `pump = "OFF"`.

### Aturan (Rules) Firebase RTDB
Karena program menggunakan `NoAuth` (tanpa login pengguna), pastikan Rules di Firebase Realtime Database mengizinkan baca/tulis (minimal untuk tahap pengembangan/praktikum):

```json
{
  "rules": {
    "monitoring": {
      ".read": true,
      ".write": true
    }
  }
}
```

---

## 7. Cara Upload & Monitoring

1. Buka `sketch_nov25a.ino` di **Arduino IDE**.
2. Pilih Board: **ESP32 Dev Module** (atau sesuai tipe board ESP32 yang digunakan) dan pilih **Port COM** yang sesuai.
3. Klik **Verify** lalu **Upload**.
4. Buka **Serial Monitor** dengan baud rate **`115200`**.

### Contoh Output Serial Monitor
```text
Connecting WiFi....
WiFi Connected!
=== SMART GARDEN READY ===
Sensor: GPIO34 | Relay: GPIO5 (Active-HIGH)
Batas Kering: > 2500 (Relay ON) | <= 2500 (Relay OFF)
Kontrol Pompa: AUTO / MANUAL via /monitoring/control
--------------------------
[Firebase Kontrol] Mode: MANUAL | Pompa Manual: OFF | Relay: OFF
Raw: 4095 | Moisture:   0% | Tanah Kering | Mode: MANUAL | Relay OFF
```

---

## 8. Troubleshooting Singkat

- **`[Firebase Error - ...]` muncul di Serial Monitor**: periksa koneksi internet WiFi, `DATABASE_URL`, dan pastikan Rules Firebase RTDB mengizinkan akses `.read` & `.write` pada `/monitoring`.
- **Relay terbalik (status `OFF` tapi pompa malah menyala)**: ubah `#define RELAY_ACTIVE_LOW` dari `false` menjadi `true`, atau pastikan kabel pompa terpasang di terminal **`NO`** (bukan `NC`).
- **Nilai `Raw` selalu `4095` atau `< 600`**: periksa kabel power (`VCC`/`GND`) dan kabel sinyal `AO` sensor tanah ke **GPIO34**.
