#define ENABLE_DATABASE                                      // Aktifkan fitur Realtime Database di FirebaseClient

#include <WiFi.h>                                            // Library koneksi WiFi ESP32
#include <WiFiClientSecure.h>                                // Library klien HTTPS/SSL untuk Firebase
#include <FirebaseClient.h>                                  // Library FirebaseClient (asinkron)

// ================= WIFI =================
#define WIFI_SSID "A56"                                      // Nama jaringan WiFi
#define WIFI_PASSWORD "12345678"                             // Password jaringan WiFi

// ================= FIREBASE =================
#define API_KEY "AIzaSyDnUNrgMlpBFzgLR6vnR3bN1AMie5q2q4s"    // Web API Key proyek Firebase
#define DATABASE_URL "https://firepump-6455a-default-rtdb.asia-southeast1.firebasedatabase.app/" // URL Realtime Database

// ================= PIN =================
#define RELAY_PIN 5                                          // Pin output pengendali modul relay (GPIO5)
#define SOIL_PIN 34                                          // Pin input sensor tanah (GPIO34 / ADC1, aman saat WiFi aktif)
#define RELAY_ACTIVE_LOW false                               // false = Active-HIGH (HIGH=ON, LOW=OFF); true = Active-LOW
#define DEBUG_FIREBASE false                                 // true = tampilkan log sukses Firebase di Serial Monitor

// ================= KALIBRASI SENSOR =================
const int BATAS_KERING = 2500;                               // Nilai raw > 2500 dianggap kering (Relay ON), <= 2500 basah (OFF)
const int DRY_VALUE = 3600;                                  // Nilai ADC saat tanah sangat kering (dipetakan ke 0%)
const int WET_VALUE = 1400;                                  // Nilai ADC saat tanah sangat basah (dipetakan ke 100%)

// ================= OBJEK FIREBASE =================
WiFiClientSecure ssl_client;                                 // Klien TLS/SSL untuk koneksi aman ke server Firebase

using AsyncClient = AsyncClientClass;                        // Alias tipe AsyncClientClass agar penulisan lebih singkat
AsyncClient aClient(ssl_client);                             // Klien asinkron Firebase menggunakan ssl_client

NoAuth no_auth;                                              // Mode tanpa autentikasi (butuh rules RTDB publik)
FirebaseApp app;                                             // Objek utama aplikasi Firebase
RealtimeDatabase Database;                                   // Objek layanan Realtime Database

unsigned long previousMillis = 0;                            // Menyimpan waktu (ms) pengiriman data terakhir
const unsigned long interval = 5000;                         // Jeda pembacaan & kirim data tiap 5000 ms (5 detik)
bool relayStatus = false;                                    // Status relay saat ini (false = OFF, true = ON)

void processData(AsyncResult &aResult);                      // Deklarasi fungsi callback hasil request Firebase

void setRelay(bool on) {                                     // Fungsi pembantu untuk menyalakan/mematikan relay
  if (RELAY_ACTIVE_LOW) {                                    // Jika modul relay bertipe Active-LOW
    digitalWrite(RELAY_PIN, on ? LOW : HIGH);                // LOW = nyala, HIGH = mati
  } else {                                                   // Jika modul relay bertipe Active-HIGH
    digitalWrite(RELAY_PIN, on ? HIGH : LOW);                // HIGH = nyala, LOW = mati
  }
}

int readSoilRaw(int samples = 10) {                          // Fungsi baca sensor tanah dengan rata-rata beberapa sampel
  long total = 0;                                            // Penampung jumlah nilai ADC sementara
  for (int i = 0; i < samples; i++) {                        // Ulangi pembacaan sebanyak 'samples' kali
    total += analogRead(SOIL_PIN);                           // Tambahkan hasil pembacaan ADC (0-4095)
    delay(10);                                               // Jeda 10 ms antar sampel agar sinyal stabil
  }
  return total / samples;                                    // Kembalikan nilai rata-rata ADC
}

void setup() {
  Serial.begin(115200);                                      // Mulai komunikasi Serial Monitor di baud rate 115200

  pinMode(RELAY_PIN, OUTPUT);                                // Atur pin relay sebagai OUTPUT
  pinMode(SOIL_PIN, INPUT);                                  // Atur pin sensor tanah sebagai INPUT
  setRelay(false);                                           // Pastikan relay dalam kondisi MATI saat ESP32 menyala

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
  Serial.println("--------------------------");              // Garis pemisah header Serial Monitor
}

void loop() {
  app.loop();                                                // Jalankan proses background/asinkron Firebase setiap iterasi

  if (app.ready() && millis() - previousMillis >= interval) { // Eksekusi tiap 5 detik jika Firebase sudah siap
    previousMillis = millis();                               // Perbarui timestamp eksekusi terakhir

    // ================= BACA & KONVERSI SENSOR =================
    int soilValue = readSoilRaw(10);                         // Baca nilai ADC mentah (rata-rata 10 sampel)

    int moisture = map(                                      // Ubah nilai ADC mentah ke skala persentase 0 - 100%
      soilValue,                                             // Nilai input ADC
      DRY_VALUE,                                             // Batas kering (0%)
      WET_VALUE,                                             // Batas basah (100%)
      0,                                                     // Output minimum (%)
      100);                                                  // Output maksimum (%)

    moisture = constrain(moisture, 0, 100);                  // Kunci hasil agar tetap di rentang 0% sampai 100%

    // ================= KONTROL RELAY =================
    bool isDry = (soilValue > BATAS_KERING);                 // true jika tanah kering (raw > 2500)
    String soilStatus = isDry ? "DRY" : "WET";               // Tentukan teks status tanah ("DRY" atau "WET")
    relayStatus = isDry;                                     // Relay ON jika tanah kering, OFF jika tanah basah

    setRelay(relayStatus);                                   // Terapkan status ON/OFF ke pin relay fisik

    // ================= SERIAL MONITOR =================
    Serial.printf("Raw: %4d | Moisture: %3d%% | %s - Relay %s\n", // Cetak ringkasan 1 baris di Serial Monitor
                  soilValue, moisture,
                  isDry ? "Tanah Kering" : "Tanah Basah ",
                  relayStatus ? "ON" : "OFF");

    if (soilValue < 600) {                                   // Peringatan jika nilai raw terlalu kecil (indikasi pin lepas)
      Serial.println("  [!] Raw terlalu rendah (<600) -> Pastikan kabel AO sudah dipindah dari Pin 15 ke GPIO34.");
    }

    // ================= KIRIM DATA KE FIREBASE =================
    Database.set<int>(                                       // Kirim nilai mentah ADC ke node /monitoring/soil/raw
      aClient,
      "/monitoring/soil/raw",
      soilValue,
      processData,
      "soilRaw");

    Database.set<int>(                                       // Kirim persentase kelembapan ke /monitoring/soil/moisture
      aClient,
      "/monitoring/soil/moisture",
      moisture,
      processData,
      "soilMoisture");

    Database.set<String>(                                    // Kirim status tanah ("DRY"/"WET") ke /monitoring/soil/status
      aClient,
      "/monitoring/soil/status",
      soilStatus,
      processData,
      "soilStatus");

    Database.set<String>(                                    // Kirim status relay ("ON"/"OFF") ke /monitoring/relay/status
      aClient,
      "/monitoring/relay/status",
      relayStatus ? "ON" : "OFF",
      processData,
      "relayStatus");
  }
}

// ================= CALLBACK FIREBASE =================
void processData(AsyncResult &aResult) {                     // Dipanggil otomatis saat ada respons/error dari Firebase
  if (!aResult.isResult()) return;                           // Abaikan jika belum ada hasil yang valid

  if (aResult.isError()) {                                   // Cek apakah terjadi error saat kirim data
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
