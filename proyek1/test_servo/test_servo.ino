#include <ESP32Servo.h>                                      // Library Servo khusus ESP32 (install: "ESP32Servo" by Kevin Harrington)

// ================= PIN SERVO =================
// Kabel Servo:
// - Oranye / Kuning / Putih (Signal) -> GPIO13
// - Merah (VCC)                      -> VIN / 5V (JANGAN 3V3!)
// - Cokelat / Hitam (GND)            -> GND ESP32 (wajib common ground)
#define SERVO_PIN 13

Servo testServo;

void setup() {
  Serial.begin(115200);
  delay(500);

  // Alokasikan timer PWM ESP32 secara eksplisit
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  ESP32PWM::allocateTimer(2);
  ESP32PWM::allocateTimer(3);

  testServo.setPeriodHertz(50);                              // Frekuensi standar servo 50 Hz
  int channel = testServo.attach(SERVO_PIN, 500, 2400);      // Rentang pulsa 500 - 2400 us (SG90 / MG90S / MG996R)

  Serial.println("\n=== TEST SERVO ESP32 ===");
  Serial.printf("Pin: GPIO%d | Attached: %s (channel: %d)\n",
                SERVO_PIN, testServo.attached() ? "YA" : "TIDAK", channel);
}

void loop() {
  Serial.println("Gerak ke 0 derajat...");
  testServo.write(0);
  delay(2000);

  Serial.println("Gerak ke 90 derajat...");
  testServo.write(90);
  delay(2000);

  Serial.println("Gerak ke 180 derajat...");
  testServo.write(180);
  delay(2000);

  Serial.println("Kembali ke 90 derajat...");
  testServo.write(90);
  delay(2000);
}
