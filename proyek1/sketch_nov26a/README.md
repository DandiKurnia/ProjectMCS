# Smart Locker ESP32 (RFID RC522 + Servo + Firebase RTDB)

Program mikrokontroler **ESP32** (`sketch_nov26a.ino`) untuk sistem **Smart Locker** menggunakan pembaca kartu **RFID RC522** dan aktuator pengunci **Motor Servo**, terintegrasi secara real-time dengan **Firebase Realtime Database (`locker-b9df4`)** dan aplikasi **Flutter Smart Locker** (`proyek1/locker`).

---

## 1. Perangkat Keras yang Dibutuhkan

- **ESP32 DevKit**
- **Modul RFID RC522** (13.56 MHz) + Kartu / Tag RFID
- **Motor Servo** (SG90 / MG90S / MG996R)
- **Catu daya 5V eksternal** *(disarankan jika memakai servo berarus besar seperti MG996R)*
- Kabel jumper & breadboard

---

## 2. Konfigurasi Pin (Wiring)

### A. ESP32 ↔ RFID RC522 (VSPI)
| Pin RFID RC522 | Pin ESP32 | Keterangan |
| :--- | :--- | :--- |
| **SDA / SS** | **GPIO5** | Slave Select (VSPI CS) |
| **SCK** | **GPIO18** | VSPI Clock |
| **MOSI** | **GPIO23** | VSPI MOSI |
| **MISO** | **GPIO19** | VSPI MISO |
| **RST** | **GPIO27** | Reset *(GPIO21 & GPIO22 dibiarkan kosong agar tetap bebas untuk I2C)* |
| **IRQ** | *(kosong)* | Tidak perlu dihubungkan |
| **3.3V** | **3V3** | **Wajib 3.3V — jangan sambungkan ke 5V!** |
| **GND** | **GND** | Ground |

### B. ESP32 ↔ Motor Servo
| Kabel Servo | Pin ESP32 | Keterangan |
| :--- | :--- | :--- |
| **Sinyal** *(Oranye / Kuning / Putih)* | **GPIO13** | Output PWM (`SERVO_PIN`) |
| **VCC** *(Merah)* | **5V / VIN** | Gunakan 5V (atau adaptor 5V eksternal untuk MG996R). Jangan pakai `3V3`. |
| **GND** *(Cokelat / Hitam)* | **GND** | Wajib terhubung ke GND ESP32 (*common ground*). |

---

## 3. Board & Library Arduino IDE

### Board Package (Boards Manager)
- **esp32** by *Espressif Systems*  
  Sudah menyertakan library bawaan:
  - `WiFi.h` — koneksi WiFi ESP32
  - `WiFiClientSecure.h` — koneksi HTTPS/TLS ke Firebase
  - `SPI.h` — komunikasi SPI untuk modul RFID RC522

### Library Eksternal (Library Manager)
| Library | Author | Fungsi |
| :--- | :--- | :--- |
| **FirebaseClient** | *Mobizt* | Komunikasi baca/tulis/push ke Firebase Realtime Database (`#define ENABLE_DATABASE`). |
| **MFRC522** | *GithubCommunity* | Membaca UID dan tipe kartu/tag RFID RC522. |
| **ESP32Servo** | *Kevin Harrington* | Mengendalikan sinyal PWM 50 Hz untuk motor servo pada ESP32. |

---

## 4. Konfigurasi Utama di `sketch_nov26a.ino`

Sesuaikan pengaturan berikut sebelum *Upload*:

```cpp
// WiFi
#define WIFI_SSID     "A56"
#define WIFI_PASSWORD "12345678"

// Firebase (proyek1/locker -> locker-b9df4)
#define API_KEY      "AIzaSyDUAR4UOcA034u3MsgWJcGDunC0PJfDuqU"
#define DATABASE_URL "https://locker-b9df4-default-rtdb.asia-southeast1.firebasedatabase.app/"
#define DEBUG_FIREBASE false     // ubah ke true untuk melihat detail respons Firebase

// Pengaturan Servo & Timer
#define SERVO_PIN 13
const int SERVO_LOCK_ANGLE = 0;          // Sudut terkunci (0 derajat)
const int SERVO_UNLOCK_ANGLE = 90;       // Sudut terbuka (90 derajat)
const unsigned long autoLockDelayMs = 5000;  // Auto-lock 5 detik (set 0 untuk nonaktif)
const unsigned long commandInterval = 1500;  // Interval cek perintah Flutter (1.5 detik)
const unsigned long scanDelayMs = 1500;      // Debounce tap kartu RFID (1.5 detik)
```

---

## 5. Struktur Data & Rules Firebase RTDB

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

### Penjelasan Node & Alur Kerja
- **`/locker/status`** *(ditulis ESP32)*: menyimpan status loker (`LOCKED` / `UNLOCKED`), sumber aksi (`BOOT`, `RFID`, `APP`, `AUTO_LOCK`), UID kartu terakhir yang di-tap (`lastUid`), dan hasil akses (`GRANTED` / `DENIED` / `NONE`).
- **`/locker/control/command`** *(ditulis Flutter, dieksekusi & direset ESP32)*:
  - `"OPEN"` → ESP32 menggerakkan servo ke `90°`, lalu mereset `command` ke `"NONE"`.
  - `"CLOSE"` → ESP32 menggerakkan servo ke `0°`, lalu mereset `command` ke `"NONE"`.
- **`/locker/cards/<UID-KEY>`** *(dikelola Flutter, dibaca ESP32)*:
  - Key menggunakan tanda hubung `-` (misal `AA-BB-CC-DD`) agar aman sebagai key node Firebase.
  - Saat kartu di-tap, ESP32 mengecek `/locker/cards/<UID-KEY>/active`. Jika `true`, akses diterima dan loker dibuka/dikunci; jika tidak ada atau `false`, akses ditolak.
- **`/locker/logs`** *(di-push ESP32)*: mencatat setiap aktivitas buka/kunci/ditolak menggunakan *server timestamp* Firebase (`{".sv": "timestamp"}`).
- **Auto-Lock**: jika loker terbuka selama `5 detik`, ESP32 otomatis mengembalikan servo ke `0°` dan mencatat log `AUTO_LOCK`.

### Aturan (Rules) Firebase RTDB
Karena ESP32 menggunakan `NoAuth`, pastikan Rules pada Firebase Console (`locker-b9df4`) mengizinkan akses pada node `/locker`:

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

## 6. Cara Upload & Monitoring

1. Buka `sketch_nov26a.ino` di **Arduino IDE**.
2. Pilih Board: **ESP32 Dev Module** dan pilih **Port COM** yang sesuai.
3. Klik **Verify** lalu **Upload** *(jika memakai servo yang ditenagai dari `VIN`, cabut sementara kabel `VCC` servo saat upload agar tegangan USB tidak drop)*.
4. Buka **Serial Monitor** dengan baud rate **`115200`**.

### Contoh Output Serial Monitor
```text
Connecting WiFi....
WiFi Connected!

=== SMART LOCKER ESP32 READY ===
RFID  -> SS:GPIO5 | RST:GPIO27 | SCK:GPIO18 | MOSI:GPIO23 | MISO:GPIO19
Servo -> Signal:GPIO13 | Lock:0 deg | Unlock:90 deg
Versi Firmware RC522: 0x92 (OK)
Firebase Node: /locker (status, control, cards, logs)
--------------------------------------
[Firebase] Terhubung & status awal terkirim (LOCKED).
Kartu RFID Terdeteksi!
  UID : AA:BB:CC:DD
  Status : AKSES DITERIMA (Kartu Utama)
  [SERVO] Loker TERBUKA (90 deg) | Sumber: RFID
  [SERVO] Otomatis terkunci kembali dalam 5 detik...
```

---

## 7. Troubleshooting Singkat

- **Gagal Upload (`Failed to connect to ESP32: No serial data received`)**: cabut sementara kabel `VCC` servo saat upload, lalu tahan tombol **`BOOT`** di ESP32 ketika muncul `Connecting.....` hingga tulisan berubah menjadi `Writing at 0x...`.
- **`Versi Firmware RC522: 0x00` atau `0xFF`**: periksa kabel SPI (`GPIO5, 18, 19, 23, 27`) dan pastikan `VCC` RC522 terhubung ke **`3V3`**.
- **Servo tidak bergerak / ESP32 sering restart**: pastikan kabel merah servo di **`5V`/`VIN`** (atau adaptor 5V eksternal dengan GND digabung ke GND ESP32) dan sinyal di **`GPIO13`**.
- **`[Firebase Error - ...]` muncul di Serial Monitor**: periksa koneksi internet WiFi, `DATABASE_URL`, dan pastikan Rules RTDB pada `/locker` sudah `.read: true` dan `.write: true`.
