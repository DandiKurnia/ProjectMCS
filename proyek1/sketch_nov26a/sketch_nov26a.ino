#define ENABLE_DATABASE                                      // Aktifkan fitur Realtime Database di FirebaseClient

#include <WiFi.h>                                            // Library koneksi WiFi ESP32
#include <WiFiClientSecure.h>                                // Library klien HTTPS/SSL untuk Firebase
#include <FirebaseClient.h>                                  // Library FirebaseClient by Mobizt
#include <SPI.h>                                             // Library komunikasi SPI bawaan ESP32
#include <MFRC522.h>                                         // Library RFID RC522 (install: "MFRC522" by GithubCommunity)
#include <ESP32Servo.h>                                      // Library Servo ESP32 (install: "ESP32Servo" by Kevin Harrington)

// ================= WIFI =================
#define WIFI_SSID     "A56"                                  // Nama jaringan WiFi
#define WIFI_PASSWORD "12345678"                             // Password jaringan WiFi

// ================= FIREBASE (proyek1/locker -> locker-b9df4) =================
#define API_KEY      "AIzaSyDUAR4UOcA034u3MsgWJcGDunC0PJfDuqU" // Web API Key proyek Firebase locker-b9df4
#define DATABASE_URL "https://locker-b9df4-default-rtdb.asia-southeast1.firebasedatabase.app/" // URL Realtime Database
#define DEBUG_FIREBASE false                                 // true = tampilkan detail log Firebase di Serial Monitor

// ================= PIN RFID RC522 (ESP32 VSPI) =================
// Catatan: Gunakan 3.3V untuk VCC RC522 (JANGAN sambungkan ke 5V!)
// Pin GPIO21 & GPIO22 dibiarkan kosong agar tetap bisa dipakai I2C (LCD/OLED) jika diperlukan.
#define RFID_SS_PIN   5                                      // Pin SDA / SS  -> GPIO5
#define RFID_RST_PIN  27                                     // Pin RST       -> GPIO27
#define RFID_SCK_PIN  18                                     // Pin SCK       -> GPIO18 (VSPI SCK)
#define RFID_MOSI_PIN 23                                     // Pin MOSI      -> GPIO23 (VSPI MOSI)
#define RFID_MISO_PIN 19                                     // Pin MISO      -> GPIO19 (VSPI MISO)

// ================= PIN & PENGATURAN SERVO =================
// Catatan: Sambungkan VCC Servo (merah) ke 5V/VIN (atau adaptor 5V eksternal) & GND bersama ESP32
#define SERVO_PIN     13                                     // Pin sinyal Servo (oranye/kuning) -> GPIO13

const int SERVO_LOCK_ANGLE = 0;                              // Sudut servo saat posisi TERKUNCI (0 derajat)
const int SERVO_UNLOCK_ANGLE = 90;                           // Sudut servo saat posisi TERBUKA (90 derajat)
const unsigned long autoLockDelayMs = 5000;                  // Otomatis mengunci kembali setelah 5000 ms (5 detik); set 0 untuk nonaktif

// ================= OBJEK HARDWARE =================
MFRC522 rfid(RFID_SS_PIN, RFID_RST_PIN);                     // Objek modul RFID RC522
Servo lockerServo;                                           // Objek motor servo pengunci loker

// ================= OBJEK FIREBASE =================
WiFiClientSecure ssl_client;                                 // Klien TLS/SSL untuk koneksi aman ke server Firebase
using AsyncClient = AsyncClientClass;
AsyncClient aClient(ssl_client);                             // Klien Firebase menggunakan ssl_client

NoAuth no_auth;                                              // Mode tanpa autentikasi (pastikan Rules RTDB /locker mengizinkan baca/tulis)
FirebaseApp app;                                             // Objek utama aplikasi Firebase
RealtimeDatabase Database;                                   // Objek layanan Realtime Database

// ================= TIMING & STATUS =================
unsigned long lastScanMillis = 0;                            // Debounce pembacaan kartu RFID
const unsigned long scanDelayMs = 1500;                      // Jeda minimal 1.5 detik antar tap kartu

unsigned long previousCommandMillis = 0;                     // Timestamp pengecekan perintah dari Flutter terakhir
const unsigned long commandInterval = 1500;                  // Cek /locker/control/command tiap 1.5 detik

bool initialSyncDone = false;                                // Penanda sinkronisasi status awal saat Firebase siap
bool isLockerOpen = false;                                   // Status loker saat ini (false = terkunci, true = terbuka)
unsigned long unlockMillis = 0;                              // Timestamp saat loker dibuka (untuk timer auto-lock)

void processData(AsyncResult &aResult);                      // Deklarasi callback inisialisasi Firebase

// Normalisasi string respons Firebase (hapus spasi & tanda kutip, ubah ke huruf kapital)
String normalizeUpper(String value) {
  value.trim();
  value.replace("\"", "");
  value.toUpperCase();
  return value;
}

// Hapus tanda kutip luar tanpa mengubah huruf besar/kecil (untuk nama kartu)
String stripQuotes(String value) {
  value.trim();
  if (value.startsWith("\"") && value.endsWith("\"") && value.length() >= 2) {
    value = value.substring(1, value.length() - 1);
  }
  return value;
}

// Escape karakter khusus JSON sederhana agar payload log selalu valid
String escapeJson(String value) {
  value.replace("\\", "\\\\");
  value.replace("\"", "\\\"");
  return value;
}

// Ubah byte array UID menjadi format tampilan "AA:BB:CC:DD"
String formatUidDisplay(byte *buffer, byte bufferSize) {
  String uid = "";
  for (byte i = 0; i < bufferSize; i++) {
    if (i > 0) uid += ":";
    if (buffer[i] < 0x10) uid += "0";
    uid += String(buffer[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

// Ubah "AA:BB:CC:DD" menjadi key aman untuk node Firebase "AA-BB-CC-DD"
String uidToFirebaseKey(String uidDisplay) {
  uidDisplay.replace(":", "-");
  uidDisplay.replace(" ", "-");
  uidDisplay.toUpperCase();
  return uidDisplay;
}

void logClientError(const char *label) {
  Serial.printf("[Firebase Error - %s] %s (code: %d)\n",
                label,
                aClient.lastError().message().c_str(),
                aClient.lastError().code());
}

// Perbarui status loker di node /locker/status
void syncLockerStatus(const String &source, const String &lastUid = "", const String &lastAccess = "") {
  if (WiFi.status() != WL_CONNECTED || !app.ready()) return;

  if (!Database.set<String>(aClient, "/locker/status/state", isLockerOpen ? "UNLOCKED" : "LOCKED")) {
    logClientError("SET status/state");
  }
  if (!Database.set<String>(aClient, "/locker/status/source", source)) {
    logClientError("SET status/source");
  }
  if (lastUid.length() > 0) {
    if (!Database.set<String>(aClient, "/locker/status/lastUid", lastUid)) {
      logClientError("SET status/lastUid");
    }
  }
  if (lastAccess.length() > 0) {
    if (!Database.set<String>(aClient, "/locker/status/lastAccess", lastAccess)) {
      logClientError("SET status/lastAccess");
    }
  }
}

// Tambahkan entri riwayat aktivitas ke /locker/logs dengan server timestamp Firebase
void pushLockerLog(const String &uid, const String &cardName, const String &action, const String &source) {
  if (WiFi.status() != WL_CONNECTED || !app.ready()) return;

  String json = "{";
  json += "\"uid\":\"" + escapeJson(uid) + "\",";
  json += "\"cardName\":\"" + escapeJson(cardName) + "\",";
  json += "\"action\":\"" + escapeJson(action) + "\",";
  json += "\"source\":\"" + escapeJson(source) + "\",";
  json += "\"timestamp\":{\".sv\":\"timestamp\"}";
  json += "}";

  Database.push<object_t>(aClient, "/locker/logs", object_t(json));
  if (aClient.lastError().code() != 0) {
    logClientError("PUSH logs");
  }
}

// Buka loker (gerakkan servo ke sudut terbuka + kirim status & log ke Firebase)
void unlockLocker(const String &source, const String &uid, const String &cardName) {
  lockerServo.write(SERVO_UNLOCK_ANGLE);
  isLockerOpen = true;
  unlockMillis = millis();

  Serial.printf("  [SERVO] Loker TERBUKA (%d deg) | Sumber: %s\n", SERVO_UNLOCK_ANGLE, source.c_str());
  if (autoLockDelayMs > 0) {
    Serial.printf("  [SERVO] Otomatis terkunci kembali dalam %lu detik...\n", autoLockDelayMs / 1000);
  }

  syncLockerStatus(source, uid == "-" ? "" : uid, source == "RFID" ? "GRANTED" : "");
  pushLockerLog(uid, cardName, "UNLOCK", source);
}

// Kunci loker (kembalikan servo ke sudut terkunci + kirim status & log ke Firebase)
void lockLocker(const String &source, const String &uid, const String &cardName) {
  lockerServo.write(SERVO_LOCK_ANGLE);
  isLockerOpen = false;

  Serial.printf("  [SERVO] Loker TERKUNCI (%d deg) | Sumber: %s\n", SERVO_LOCK_ANGLE, source.c_str());

  syncLockerStatus(source, uid == "-" ? "" : uid, source == "RFID" ? "GRANTED" : "");
  pushLockerLog(uid, cardName, "LOCK", source);
}

// Cek apakah UID kartu terdaftar & aktif di /locker/cards/<UID-KEY>
bool isCardAuthorized(const String &uidDisplay, String &outCardName) {
  outCardName = "Tidak Terdaftar";
  if (WiFi.status() != WL_CONNECTED || !app.ready()) return false;

  String key = uidToFirebaseKey(uidDisplay);
  String activePath = "/locker/cards/" + key + "/active";
  String activeVal = Database.get<String>(aClient, activePath);

  if (aClient.lastError().code() != 0) {
    logClientError("GET card/active");
    return false;
  }

  String normalized = normalizeUpper(activeVal);
  if (normalized != "TRUE" && normalized != "1") {
    return false;
  }

  String namePath = "/locker/cards/" + key + "/name";
  String nameVal = stripQuotes(Database.get<String>(aClient, namePath));
  if (aClient.lastError().code() == 0 && nameVal.length() > 0 && nameVal != "null") {
    outCardName = nameVal;
  } else {
    outCardName = "Kartu Terdaftar";
  }
  return true;
}

// Cek perintah Buka / Kunci jarak jauh dari aplikasi Flutter di /locker/control/command
void checkRemoteCommand() {
  if (WiFi.status() != WL_CONNECTED || !app.ready()) return;

  String cmd = Database.get<String>(aClient, "/locker/control/command");
  if (aClient.lastError().code() != 0) {
    logClientError("GET control/command");
    return;
  }

  cmd = normalizeUpper(cmd);
  if (cmd.length() == 0 || cmd == "NULL") {
    Database.set<String>(aClient, "/locker/control/command", "NONE");
    return;
  }

  if (cmd == "OPEN") {
    Serial.println("[Firebase Kontrol] Perintah OPEN diterima dari Aplikasi");
    Database.set<String>(aClient, "/locker/control/command", "NONE");
    unlockLocker("APP", "-", "Aplikasi Flutter");
  } else if (cmd == "CLOSE") {
    Serial.println("[Firebase Kontrol] Perintah CLOSE diterima dari Aplikasi");
    Database.set<String>(aClient, "/locker/control/command", "NONE");
    lockLocker("APP", "-", "Aplikasi Flutter");
  }
}

void setup() {
  Serial.begin(115200);
  delay(500);

  // ================= INISIALISASI SERVO =================
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  ESP32PWM::allocateTimer(2);
  ESP32PWM::allocateTimer(3);

  lockerServo.setPeriodHertz(50);
  lockerServo.attach(SERVO_PIN, 500, 2400);
  lockerServo.write(SERVO_LOCK_ANGLE);                       // Posisi awal: TERKUNCI
  isLockerOpen = false;

  // ================= INISIALISASI RFID RC522 =================
  SPI.begin(RFID_SCK_PIN, RFID_MISO_PIN, RFID_MOSI_PIN, RFID_SS_PIN);
  rfid.PCD_Init();
  delay(100);

  // ================= KONEKSI WIFI =================
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(500);
  }
  Serial.println("\nWiFi Connected!");

  // ================= INISIALISASI FIREBASE =================
  ssl_client.setInsecure();
  initializeApp(aClient, app, getAuth(no_auth), processData, "init");
  app.getApp<RealtimeDatabase>(Database);
  Database.url(DATABASE_URL);

  Serial.println("\n=== SMART LOCKER ESP32 READY ===");
  Serial.printf("RFID  -> SS:GPIO%d | RST:GPIO%d | SCK:GPIO%d | MOSI:GPIO%d | MISO:GPIO%d\n",
                RFID_SS_PIN, RFID_RST_PIN, RFID_SCK_PIN, RFID_MOSI_PIN, RFID_MISO_PIN);
  Serial.printf("Servo -> Signal:GPIO%d | Lock:%d deg | Unlock:%d deg\n",
                SERVO_PIN, SERVO_LOCK_ANGLE, SERVO_UNLOCK_ANGLE);

  byte version = rfid.PCD_ReadRegister(MFRC522::VersionReg);
  Serial.printf("Versi Firmware RC522: 0x%02X %s\n",
                version, (version == 0x00 || version == 0xFF) ? "(GAGAL - Cek kabel SPI/3.3V!)" : "(OK)");
  Serial.println("Firebase Node: /locker (status, control, cards, logs)");
  Serial.println("--------------------------------------");
}

void loop() {
  app.loop();

  // Sinkronisasi awal saat Firebase pertama kali siap
  if (app.ready() && !initialSyncDone) {
    initialSyncDone = true;
    Database.set<String>(aClient, "/locker/control/command", "NONE");
    syncLockerStatus("BOOT", "-", "NONE");
    previousCommandMillis = millis();
    Serial.println("[Firebase] Terhubung & status awal terkirim (LOCKED).");
  }

  // 1. Cek timer auto-lock (non-blocking)
  if (isLockerOpen && autoLockDelayMs > 0 && (millis() - unlockMillis >= autoLockDelayMs)) {
    Serial.println("[AUTO-LOCK] Waktu habis, mengunci loker...");
    lockLocker("AUTO_LOCK", "-", "Auto-Lock");
    Serial.println("--------------------------------------");
  }

  // 2. Cek perintah jarak jauh dari aplikasi Flutter tiap 1.5 detik
  if (app.ready() && (millis() - previousCommandMillis >= commandInterval)) {
    checkRemoteCommand();
    previousCommandMillis = millis();
  }

  // 3. Cek apakah ada kartu RFID yang ditempelkan
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) {
    return;
  }

  unsigned long now = millis();
  if (now - lastScanMillis < scanDelayMs) {
    rfid.PICC_HaltA();
    rfid.PCD_StopCrypto1();
    return;
  }
  lastScanMillis = now;

  String uid = formatUidDisplay(rfid.uid.uidByte, rfid.uid.size);
  Serial.println("Kartu RFID Terdeteksi!");
  Serial.printf("  UID : %s\n", uid.c_str());

  // 4. Validasi UID kartu ke Firebase (/locker/cards/<UID-KEY>)
  String cardName = "";
  if (isCardAuthorized(uid, cardName)) {
    Serial.printf("  Status : AKSES DITERIMA (%s)\n", cardName.c_str());
    if (isLockerOpen) {
      lockLocker("RFID", uid, cardName);
    } else {
      unlockLocker("RFID", uid, cardName);
    }
  } else {
    Serial.println("  Status : AKSES DITOLAK (kartu tidak terdaftar / nonaktif)");
    syncLockerStatus("RFID", uid, "DENIED");
    pushLockerLog(uid, "Tidak Terdaftar", "DENIED", "RFID");
  }
  Serial.println("--------------------------------------");

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}

// ================= CALLBACK INISIALISASI FIREBASE =================
void processData(AsyncResult &aResult) {
  if (!aResult.isResult()) return;

  if (aResult.isError()) {
    Serial.print("[Firebase Error] ");
    Serial.println(aResult.error().message());
  }

#if DEBUG_FIREBASE
  if (aResult.available()) {
    Serial.print("[Firebase OK] ");
    Serial.println(aResult.c_str());
  }
#endif
}
