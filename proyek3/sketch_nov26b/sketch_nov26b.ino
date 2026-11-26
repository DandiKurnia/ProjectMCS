#define ENABLE_DATABASE                                      // Aktifkan fitur Realtime Database di FirebaseClient

#include <WiFi.h>                                            // Library koneksi WiFi ESP32
#include <WiFiClientSecure.h>                                // Library klien HTTPS/SSL untuk Firebase
#include <FirebaseClient.h>                                  // Library FirebaseClient by Mobizt

// ================= WIFI =================
#define WIFI_SSID     "A56"                                  // Nama jaringan WiFi
#define WIFI_PASSWORD "12345678"                             // Password jaringan WiFi

// ================= FIREBASE (proyek3/floodly -> floodly-27cd8) =================
#define API_KEY      "AIzaSyCxNXS0egPsCNju5r0SNYR-zZgJSuE66o8" // Web API Key proyek Firebase floodly-27cd8
#define DATABASE_URL "https://floodly-27cd8-default-rtdb.asia-southeast1.firebasedatabase.app/" // URL Realtime Database (asia-southeast1)
#define DEBUG_FIREBASE false                                 // true = tampilkan detail log Firebase di Serial Monitor

// ================= PIN ULTRASONIC HC-SR04 & BUZZER (ESP32) =================
#define TRIG_PIN   5                                         // Pin TRIG Ultrasonic -> GPIO5 (OUTPUT)
#define ECHO_PIN   18                                        // Pin ECHO Ultrasonic -> GPIO18 (INPUT)
#define BUZZER_PIN 19                                        // Pin Buzzer Aktif (+ / S) -> GPIO19 (OUTPUT)

// ================= PENGATURAN BUZZER AKTIF =================
#define BUZZER_ACTIVE_LOW false                              // false = Active-HIGH (HIGH=bunyi, LOW=mati), true = Active-LOW (LOW=bunyi, HIGH=mati)

// ================= PARAMETER KETINGGIAN AIR =================
const float BATAS_BAHAYA_CM = 5.0;                           // Jika jarak air ke ultrasonic <= 5.0 cm -> Status BAHAYA & Buzzer BUNYI
const float TINGGI_SENSOR_CM = 20.0;                         // Tinggi posisi sensor dari dasar wadah (cm), sesuaikan dengan wadah Anda

// ================= OBJEK FIREBASE =================
WiFiClientSecure ssl_client;                                 // Klien TLS/SSL untuk koneksi aman ke server Firebase
using AsyncClient = AsyncClientClass;
AsyncClient aClient(ssl_client);                             // Klien Firebase menggunakan ssl_client

NoAuth no_auth;                                              // Mode tanpa autentikasi (pastikan Rules RTDB /floodly mengizinkan baca/tulis)
FirebaseApp app;                                             // Objek utama aplikasi Firebase
RealtimeDatabase Database;                                   // Objek layanan Realtime Database

// ================= TIMING & STATUS =================
unsigned long previousReadMillis = 0;                        // Timestamp pembacaan sensor ultrasonic terakhir
const unsigned long readIntervalMs = 500;                    // Interval pembacaan sensor & kontrol buzzer (0.5 detik)

unsigned long previousFirebaseMillis = 0;                    // Timestamp pengiriman data ke Firebase terakhir
const unsigned long firebaseIntervalMs = 2000;               // Interval kirim data ke Firebase (2 detik)

bool lastDangerState = false;                                // Menyimpan status bahaya terakhir untuk deteksi perubahan cepat
bool hasSentInitialData = false;                             // Penanda data pertama sudah terkirim ke Firebase

void processData(AsyncResult &aResult);                      // Deklarasi callback inisialisasi Firebase

// Fungsi menyalakan atau mematikan buzzer aktif
void setBuzzer(bool on) {
  if (BUZZER_ACTIVE_LOW) {
    digitalWrite(BUZZER_PIN, on ? LOW : HIGH);               // Active-LOW: LOW = bunyi, HIGH = mati
  } else {
    digitalWrite(BUZZER_PIN, on ? HIGH : LOW);               // Active-HIGH: HIGH = bunyi, LOW = mati
  }
}

void logClientError(const char *label) {
  Serial.printf("[Firebase Error - %s] %s (code: %d)\n",
                label,
                aClient.lastError().message().c_str(),
                aClient.lastError().code());
}

// Fungsi baca 1 sampel jarak dari HC-SR04 dalam satuan cm (-1 jika gagal/timeout)
float readSingleDistanceCm() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);                              // Kirim pulsa trigger 10 mikrodetik
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  unsigned long duration = pulseIn(ECHO_PIN, HIGH, 30000);   // Timeout 30.000 us (jarak maks ~5 meter)
  if (duration == 0) {
    return -1.0f;
  }

  float distance = (duration * 0.0343f) / 2.0f;              // Kecepatan suara 0.0343 cm/us dibagi 2 (pulang-pergi)
  if (distance < 2.0f || distance > 400.0f) {
    return -1.0f;
  }
  return distance;
}

// Fungsi baca rata-rata beberapa sampel agar hasil jarak lebih stabil
float readDistanceCm(int samples = 5) {
  float total = 0.0f;
  int validCount = 0;

  for (int i = 0; i < samples; i++) {
    float d = readSingleDistanceCm();
    if (d > 0.0f) {
      total += d;
      validCount++;
    }
    delay(25);
  }

  if (validCount == 0) {
    return -1.0f;
  }
  return total / validCount;
}

// Kirim seluruh data monitoring ketinggian air secara atomik ke node /floodly
void sendFloodDataToFirebase(float distanceCm, float waterLevelCm, int percent, bool isDanger) {
  if (WiFi.status() != WL_CONNECTED || !app.ready()) return;

  char json[256];
  snprintf(json, sizeof(json),
           "{\"distanceCm\":%.1f,\"waterLevelCm\":%.1f,\"sensorHeightCm\":%.1f,"
           "\"dangerThresholdCm\":%.1f,\"percent\":%d,\"status\":\"%s\",\"buzzer\":\"%s\"}",
           distanceCm,
           waterLevelCm,
           TINGGI_SENSOR_CM,
           BATAS_BAHAYA_CM,
           percent,
           isDanger ? "BAHAYA" : "AMAN",
           isDanger ? "ON" : "OFF");

  bool ok = Database.set<object_t>(aClient, "/floodly", object_t(json));
  if (!ok) {
    logClientError("SET /floodly");
  }
}

void setup() {
  Serial.begin(115200);
  delay(300);

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  digitalWrite(TRIG_PIN, LOW);
  setBuzzer(false);                                          // Pastikan buzzer mati saat ESP32 menyala

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

  Serial.println("\n=== FLOODLY - MONITOR KETINGGIAN AIR READY ===");
  Serial.printf("Ultrasonic -> TRIG: GPIO%d | ECHO: GPIO%d\n", TRIG_PIN, ECHO_PIN);
  Serial.printf("Buzzer     -> PIN : GPIO%d (Buzzer Aktif - %s)\n",
                BUZZER_PIN, BUZZER_ACTIVE_LOW ? "Active-LOW" : "Active-HIGH");
  Serial.printf("Batas Alarm: Jarak air <= %.1f cm -> Buzzer BUNYI\n", BATAS_BAHAYA_CM);
  Serial.printf("Tinggi Sensor: %.1f cm | Firebase Node: /floodly\n", TINGGI_SENSOR_CM);
  Serial.println("------------------------------------------------");
}

void loop() {
  app.loop();

  unsigned long now = millis();
  if (now - previousReadMillis < readIntervalMs) {
    return;
  }
  previousReadMillis = now;

  // 1. Baca jarak dari sensor ultrasonic ke permukaan air
  float distanceCm = readDistanceCm(5);

  if (distanceCm < 0.0f) {
    setBuzzer(false);
    Serial.println("[!] Sensor ultrasonic tidak terbaca (cek kabel VCC/GND/TRIG/ECHO atau objek terlalu dekat < 2cm)");
    return;
  }

  // 2. Hitung estimasi ketinggian air & persentase ketinggian
  float waterLevelCm = TINGGI_SENSOR_CM - distanceCm;
  if (waterLevelCm < 0.0f) waterLevelCm = 0.0f;
  if (waterLevelCm > TINGGI_SENSOR_CM) waterLevelCm = TINGGI_SENSOR_CM;

  int percent = (int)((waterLevelCm / TINGGI_SENSOR_CM) * 100.0f + 0.5f);
  percent = constrain(percent, 0, 100);

  // 3. Cek kondisi bahaya: jarak air ke ultrasonic <= 5 cm -> buzzer bunyi
  bool isDanger = (distanceCm <= BATAS_BAHAYA_CM);
  setBuzzer(isDanger);

  // 4. Tampilkan hasil di Serial Monitor
  Serial.printf("Jarak: %5.1f cm | Tinggi Air: %5.1f cm (%3d%%) | Status: %-6s | Buzzer: %s\n",
                distanceCm,
                waterLevelCm,
                percent,
                isDanger ? "BAHAYA" : "AMAN",
                isDanger ? "BUNYI" : "MATI");

  // 5. Kirim data ke Firebase segera jika status berubah, data awal, atau tiap 2 detik
  bool statusChanged = (!hasSentInitialData || isDanger != lastDangerState);
  if (app.ready() && (statusChanged || (now - previousFirebaseMillis >= firebaseIntervalMs))) {
    sendFloodDataToFirebase(distanceCm, waterLevelCm, percent, isDanger);
    lastDangerState = isDanger;
    hasSentInitialData = true;
    previousFirebaseMillis = millis();
  }
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
