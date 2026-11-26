/// Model data real-time monitoring ketinggian air dari node `/floodly` di Firebase RTDB.
class FloodData {
  const FloodData({
    required this.distanceCm,
    required this.waterLevelCm,
    required this.sensorHeightCm,
    required this.dangerThresholdCm,
    required this.percent,
    required this.status,
    required this.buzzer,
  });

  /// Jarak permukaan air ke sensor ultrasonic HC-SR04 (cm).
  final double distanceCm;

  /// Estimasi ketinggian air dari dasar wadah (cm).
  final double waterLevelCm;

  /// Tinggi pemasangan sensor dari dasar wadah (cm).
  final double sensorHeightCm;

  /// Ambang batas bahaya jarak air ke sensor (default 5.0 cm).
  final double dangerThresholdCm;

  /// Persentase ketinggian air (0 - 100%).
  final int percent;

  /// Status dari ESP32 (`AMAN` atau `BAHAYA`).
  final String status;

  /// Status buzzer aktif dari ESP32 (`ON` atau `OFF`).
  final String buzzer;

  bool get isDanger =>
      status.toUpperCase() == 'BAHAYA' || distanceCm <= dangerThresholdCm;

  bool get isBuzzerOn => buzzer.toUpperCase() == 'ON';

  static FloodData? fromSnapshot(Object? value) {
    if (value is! Map) return null;

    final distance = _toDouble(value['distanceCm']);
    if (distance == null) return null;

    final sensorHeight = _toDouble(value['sensorHeightCm']) ?? 20.0;
    final dangerThreshold = _toDouble(value['dangerThresholdCm']) ?? 5.0;
    final computedLevel = (sensorHeight - distance).clamp(0.0, sensorHeight);
    final waterLevel = _toDouble(value['waterLevelCm']) ?? computedLevel;
    final computedPercent = sensorHeight > 0
        ? ((waterLevel / sensorHeight) * 100).round().clamp(0, 100)
        : 0;
    final percent = (_toInt(value['percent']) ?? computedPercent).clamp(0, 100);

    final status = (value['status'] ?? (distance <= dangerThreshold ? 'BAHAYA' : 'AMAN'))
        .toString()
        .trim()
        .toUpperCase();
    final buzzer = (value['buzzer'] ?? (distance <= dangerThreshold ? 'ON' : 'OFF'))
        .toString()
        .trim()
        .toUpperCase();

    return FloodData(
      distanceCm: distance,
      waterLevelCm: waterLevel,
      sensorHeightCm: sensorHeight,
      dangerThresholdCm: dangerThreshold,
      percent: percent,
      status: status,
      buzzer: buzzer,
    );
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static int? _toInt(Object? value) {
    if (value is num) return value.round();
    if (value is String) return double.tryParse(value.trim())?.round();
    return null;
  }
}
