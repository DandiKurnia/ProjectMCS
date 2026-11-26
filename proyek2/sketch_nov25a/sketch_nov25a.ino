#define ENABLE_DATABASE                                      // Aktifkan fitur Realtime Database di FirebaseClient

#include <WiFi.h>                                            // Library koneksi WiFi ESP32
#include <WiFiClientSecure.h>                                // Library klien HTTPS/SSL untuk Firebase
#include <FirebaseClient.h>                                  // Library FirebaseClient

// ================= WIFI =================
#define WIFI_SSID "A56"                                      // Nama jaringan WiFi
#define WIFI_PASSWORD "12345678"                             // Password jaringan WiFi

// ================= FIREBASE =================
#define API_KEY "AIzaSyDnUNrgMlpBFzgLR6vnR3bN1AMie5q2q4s"    // Web API Key proyek Firebase
#define DATABASE_URL "https://firepump-6455a-default-rtdb.asia-southeast1.firebasedatabase.app/" // URL Realtime Database

// ================= PIN =================
#define RELAY_PIN 5                                          // Pin output pengendali modul relay (GPIO5)
#define SOIL_PIN 34                                          // Pin input sensor tanah (GPIO34 / ADC1, aman saat WiFi aktif)
#define RELAY_ACTIVE_LOW false                               // false = Active-HIGH (HIGH=ON/NO tertutup, LOW=OFF/NO terbuka)
#define DEBUG_FIREBASE false                                 // true = tampilkan log detail Firebase di Serial Monitor

// ================= KALIBRASI SENSOR =================
const int BATAS_KERING = 2500;                               // Nilai raw > 2500 dianggap kering (Relay ON), <= 2500 basah (OFF)
const int DRY_VALUE = 3600;                                  // Nilai ADC saat tanah sangat kering (dipetakan ke 0%)
const int WET_VALUE = 1400;                                  // Nilai ADC saat tanah sangat basah (dipetakan ke 100%)

// ================= OBJEK FIREBASE =================
WiFiClientSecure ssl_client;                                 // Klien TLS/SSL untuk koneksi aman ke server Firebase

using AsyncClient = AsyncClientClass;                        // Alias tipe AsyncClientClass agar penulisan lebih singkat
AsyncClient aClient(ssl_client);                             // Klien Firebase menggunakan ssl_client

NoAuth no_auth;                                              // Mode tanpa autentikasi (butuh rules RTDB publik)
FirebaseApp app;                                             // Objek utama aplikasi Firebase
RealtimeDatabase Database;                                   // Objek layanan Realtime Database

// ================= TIMING & STATUS =================
unsigned long previousSensorMillis = 0;                      // Menyimpan waktu (ms) pengiriman data sensor terakhir
const unsigned long sensorInterval = 5000;                   // Jeda pembacaan & kirim data sensor tiap 5000 ms (5 detik)

unsigned long previousControlMillis = 0;                     // Menyimpan waktu (ms) pengambilan perintah kontrol terakhir
const unsigned long controlInterval = 2000;                  // Jeda cek mode & perintah pompa manual tiap 2000 ms (2 detik)

bool initialSyncDone = false;                                // Penanda sinkronisasi awal saat Firebase pertama kali siap
bool controlSyncedOnce = false;                              // Penanda data kontrol sudah pernah berhasil dibaca

bool relayStatus = false;                                    // Status fisik relay saat ini (false = OFF/LOW, true = ON/HIGH)
bool lastSoilDry = false;                                    // Status kondisi tanah terakhir (true = kering, false = basah)
bool isManualMode = false;                                   // Mode pompa: false = AUTO (otomatis), true = MANUAL
bool manualPumpOn = false;                                   // Perintah pompa saat mode MANUAL (false = OFF, true = ON)

void processData(AsyncResult &aResult);                      // Deklarasi fungsi callback inisialisasi Firebase

void setRelay(bool on) {                                     // Fungsi pembantu untuk menyalakan/mematikan relay
  if (RELAY_ACTIVE_LOW) {                                    // Jika modul relay bertipe Active-LOW
    digitalWrite(RELAY_PIN, on ? LOW : HIGH);                // LOW = nyala, HIGH = mati
  } else {                                                   // Jika modul relay bertipe Active-HIGH (NO aktif saat HIGH)
    digitalWrite(RELAY_PIN, on ? HIGH : LOW);                // HIGH = nyala, LOW = mati
  }
}

String normalizeValue(String value) {                        // Bersihkan tanda kutip & spasi lalu ubah ke huruf kapital
  value.trim();
  value.replace("\"", "");
  value.toUpperCase();
  return value;
}

void logClientError(const char *label) {                     // Tampilkan pesan error terakhir dari AsyncClient
  Serial.printf("[Firebase Error - %s] %s (code: %d)\n",
                label,
                aClient.lastError().message().c_str(),
                aClient.lastError().code());
}

void applyRelayControl(bool syncRelayStatus = false) {       // Terapkan status relay sesuai mode AUTO atau MANUAL
  bool targetRelay = isManualMode ? manualPumpOn : lastSoilDry; // Manual ikut perintah user, Auto ikut kondisi sensor tanah
  bool changed = (targetRelay != relayStatus);               // Cek apakah status relay berubah

  relayStatus = targetRelay;                                 // Perbarui status relay saat ini
  setRelay(relayStatus);                                     // Terapkan status ON/OFF ke pin relay fisik

  if ((changed || syncRelayStatus) && app.ready()) {         // Kirim status relay fisik ke Firebase jika berubah / diminta
    bool ok = Database.set<String>(
      aClient,
      "/monitoring/relay/status",
      relayStatus ? "ON" : "OFF");
    if (!ok) {
      logClientError("SET relay/status");
    }
  }
}

bool fetchControlState() {                                   // Baca /monitoring/control/mode & /pump langsung (await mode)
  if (WiFi.status() != WL_CONNECTED) return false;

  String modeStr = Database.get<String>(aClient, "/monitoring/control/mode");
  if (aClient.lastError().code() != 0) {
    logClientError("GET control/mode");
    return false;
  }

  String pumpStr = Database.get<String>(aClient, "/monitoring/control/pump");
  if (aClient.lastError().code() != 0) {
    logClientError("GET control/pump");
    return false;
  }

  modeStr = normalizeValue(modeStr);
  pumpStr = normalizeValue(pumpStr);

#if DEBUG_FIREBASE
  Serial.printf("[Firebase GET] mode='%s' | pump='%s'\n", modeStr.c_str(), pumpStr.c_str());
#endif

  bool prevMode = isManualMode;
  bool prevManualPump = manualPumpOn;

  if (modeStr.length() == 0 || modeStr == "NULL") {          // Jika node mode belum ada di RTDB, isi default AUTO
    isManualMode = false;
    Database.set<String>(aClient, "/monitoring/control/mode", "AUTO");
  } else if (modeStr == "MANUAL") {
    isManualMode = true;
  } else if (modeStr == "AUTO") {
    isManualMode = false;
  }

  if (pumpStr.length() == 0 || pumpStr == "NULL") {          // Jika node pump belum ada di RTDB, isi default OFF
    manualPumpOn = false;
    Database.set<String>(aClient, "/monitoring/control/pump", "OFF");
  } else if (pumpStr == "ON" || pumpStr == "TRUE" || pumpStr == "1") {
    manualPumpOn = true;
  } else if (pumpStr == "OFF" || pumpStr == "FALSE" || pumpStr == "0") {
    manualPumpOn = false;
  }

  applyRelayControl(!controlSyncedOnce);                     // Terapkan ke relay fisik & sinkronkan status relay jika berubah

  if (!controlSyncedOnce || prevMode != isManualMode || prevManualPump != manualPumpOn) {
    controlSyncedOnce = true;
    Serial.printf("[Firebase Kontrol] Mode: %s | Pompa Manual: %s | Relay: %s\n",
                  isManualMode ? "MANUAL" : "AUTO",
                  manualPumpOn ? "ON" : "OFF",
                  relayStatus ? "ON" : "OFF");
  }

  return true;
}

int readSoilRaw(int samples = 10) {                          // Fungsi baca sensor tanah dengan rata-rata beberapa sampel
  long total = 0;                                            // Penampung jumlah nilai ADC sementara
  for (int i = 0; i < samples; i++) {                        // Ulangi pembacaan sebanyak 'samples' kali
    total += analogRead(SOIL_PIN);                           // Tambahkan hasil pembacaan ADC (0-4095)
    delay(10);                                               // Jeda 10 ms antar sampel agar sinyal stabil
  }
  return total / samples;                                    // Kembalikan nilai rata-rata ADC
}

void readAndSendSensorData() {                               // Baca sensor tanah, evaluasi relay, dan kirim ke Firebase
  int soilValue = readSoilRaw(10);                           // Baca nilai ADC mentah (rata-rata 10 sampel)

  int moisture = map(                                        // Ubah nilai ADC mentah ke skala persentase 0 - 100%
    soilValue,                                               // Nilai input ADC
    DRY_VALUE,                                               // Batas kering (0%)
    WET_VALUE,                                               // Batas basah (100%)
    0,                                                       // Output minimum (%)
    100);                                                    // Output maksimum (%)

  moisture = constrain(moisture, 0, 100);                    // Kunci hasil agar tetap di rentang 0% sampai 100%

  // ================= KONTROL RELAY =================
  lastSoilDry = (soilValue > BATAS_KERING);                  // true jika tanah kering (raw > 2500)
  String soilStatus = lastSoilDry ? "DRY" : "WET";           // Tentukan teks status tanah ("DRY" atau "WET")

  applyRelayControl(false);                                  // Terapkan relay fisik segera (AUTO ikut sensor, MANUAL ikut Firebase)

  // ================= SERIAL MONITOR =================
  Serial.printf("Raw: %4d | Moisture: %3d%% | %s | Mode: %-6s | Relay %s\n",
                soilValue, moisture,
                lastSoilDry ? "Tanah Kering" : "Tanah Basah ",
                isManualMode ? "MANUAL" : "AUTO",
                relayStatus ? "ON" : "OFF");

  if (soilValue < 600) {                                     // Peringatan jika nilai raw terlalu kecil (indikasi pin lepas)
    Serial.println("  [!] Raw terlalu rendah (<600) -> Pastikan kabel AO sudah dipindah dari Pin 15 ke GPIO34.");
  }

  if (WiFi.status() != WL_CONNECTED) return;

  // ================= KIRIM DATA KE FIREBASE =================
  if (!Database.set<int>(aClient, "/monitoring/soil/raw", soilValue)) {
    logClientError("SET soil/raw");
  }

  if (!Database.set<int>(aClient, "/monitoring/soil/moisture", moisture)) {
    logClientError("SET soil/moisture");
  }

  if (!Database.set<String>(aClient, "/monitoring/soil/status", soilStatus)) {
    logClientError("SET soil/status");
  }

  if (!Database.set<String>(aClient, "/monitoring/relay/status", relayStatus ? "ON" : "OFF")) {
    logClientError("SET relay/status");
  }
}

void setup() {
  Serial.begin(115200);                                      // Mulai komunikasi Serial Monitor di baud rate 115200

  pinMode(RELAY_PIN, OUTPUT);                                // Atur pin relay sebagai OUTPUT
  pinMode(SOIL_PIN, INPUT);                                  // Atur pin sensor tanah sebagai INPUT
  setRelay(false);                                           // Pastikan relay dalam kondisi MATI (LOW) saat ESP32 menyala

  analogReadResolution(12);                                  // Set resolusi ADC ESP32 ke 12-bit (rentang 0 - 4095)
  analogSetPinAttenuation(SOIL_PIN, ADC_11db);               // Set atenuasi 11dB agar ADC membaca rentang penuh 0 - 3.3V

  // ================= KONEKSI WIFI =================
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);                      // Mulai proses koneksi ke WiFi
  Serial.print("Connecting WiFi");                           // Tampilkan status sedang menghubungkan WiFi

  while (WiFi.status() != WL_CONNECTED) {                    // Tunggu hingga WiFi berhasil tersambung
    Serial.print(".");                                       // Cetak titik sebagai indikator loading
    delay(500);                                              // Tunggu 500 ms sebelum cek status WiFi lagi
  }

  Serial.println("\nWiFi Connected!");                       // Tampilkan pesan WiFi sudah terhubung

  // ================= INISIALISASI FIREBASE =================
  ssl_client.setInsecure();                                  // Lewati verifikasi sertifikat SSL (lebih praktis di ESP32)

  initializeApp(aClient, app, getAuth(no_auth), processData, "init"); // Inisialisasi FirebaseApp tanpa autentikasi
  app.getApp<RealtimeDatabase>(Database);                    // Hubungkan objek Database ke instance app Firebase
  Database.url(DATABASE_URL);                                // Atur alamat URL Realtime Database tujuan

  Serial.println("=== SMART GARDEN READY ===");              // Tampilkan header info konfigurasi di Serial Monitor
  Serial.printf("Sensor: GPIO%d | Relay: GPIO%d (%s)\n",     // Cetak pin sensor, pin relay, dan mode relay
                SOIL_PIN, RELAY_PIN, RELAY_ACTIVE_LOW ? "Active-LOW" : "Active-HIGH");
  Serial.printf("Batas Kering: > %d (Relay ON) | <= %d (Relay OFF)\n", // Cetak ambang batas relay ON/OFF
                BATAS_KERING, BATAS_KERING);
  Serial.println("Kontrol Pompa: AUTO / MANUAL via /monitoring/control");
  Serial.println("--------------------------");              // Garis pemisah header Serial Monitor
}

void loop() {
  app.loop();                                                // Jalankan proses internal FirebaseApp

  if (!app.ready()) return;                                  // Tunggu hingga FirebaseApp siap

  // Sinkronisasi awal: baca kontrol dari Firebase DULU sebelum evaluasi sensor & relay
  if (!initialSyncDone) {
    initialSyncDone = true;
    fetchControlState();
    readAndSendSensorData();
    unsigned long doneAt = millis();
    previousControlMillis = doneAt;
    previousSensorMillis = doneAt;
    return;
  }

  unsigned long now = millis();

  // Cek perubahan mode (AUTO/MANUAL) & perintah pompa manual tiap 2 detik
  if (now - previousControlMillis >= controlInterval) {
    fetchControlState();
    previousControlMillis = millis();
  }

  // Baca sensor tanah & kirim data monitoring ke Firebase tiap 5 detik
  if (now - previousSensorMillis >= sensorInterval) {
    readAndSendSensorData();
    previousSensorMillis = millis();
  }
}

// ================= CALLBACK INISIALISASI FIREBASE =================
void processData(AsyncResult &aResult) {                     // Callback untuk initializeApp
  if (!aResult.isResult()) return;                           // Abaikan jika belum ada hasil yang valid

  if (aResult.isError()) {                                   // Cek apakah terjadi error saat inisialisasi
    Serial.print("[Firebase Error] ");                       // Cetak label error di Serial Monitor
    Serial.println(aResult.error().message());               // Cetak detail pesan error dari Firebase
  }

#if DEBUG_FIREBASE                                           // Hanya aktif jika DEBUG_FIREBASE bernilai true
  if (aResult.available()) {                                 // Cek apakah ada payload respons dari server
    Serial.print("[Firebase OK] ");                          // Cetak label sukses
    Serial.println(aResult.c_str());                         // Cetak isi respons dari Firebase
  }
#endif
}
