/// Mode pengendalian pompa air pada ESP32.
/// - [auto]: pompa mengikuti pembacaan sensor kelembapan tanah.
/// - [manual]: pompa dikendalikan langsung oleh pengguna dari aplikasi Flutter.
enum PumpMode { auto, manual }

/// Model data terstruktur untuk isi node `/monitoring` di Firebase RTDB.
class MonitoringData {
  const MonitoringData({
    required this.moisture,
    required this.raw,
    required this.soilStatus,
    required this.relayStatus,
    this.pumpMode = PumpMode.auto,
    this.manualPumpOn = false,
  });

  /// Persentase kelembapan tanah (0 - 100%).
  final int moisture;

  /// Nilai mentah ADC 12-bit dari sensor tanah ESP32 (0 - 4095).
  final int raw;

  /// Status teks kondisi tanah dari ESP32 (`DRY` atau `WET`).
  final String soilStatus;

  /// Status aktual relay fisik dari ESP32 (`ON` atau `OFF`).
  final String relayStatus;

  /// Mode aktif kontrol pompa (`PumpMode.auto` atau `PumpMode.manual`).
  final PumpMode pumpMode;

  /// Perintah sakelar pompa yang tersimpan di `/monitoring/control/pump`.
  final bool manualPumpOn;

  /// Bernilai `true` jika sensor melaporkan tanah kering (`DRY`).
  bool get isDry => soilStatus.toUpperCase() == 'DRY';

  /// Bernilai `true` jika relay fisik ESP32 sedang menyala (`ON`).
  bool get isRelayOn => relayStatus.toUpperCase() == 'ON';

  /// Bernilai `true` jika pompa sedang dalam mode kontrol manual.
  bool get isManualMode => pumpMode == PumpMode.manual;

  /// Bernilai `true` jika pompa sedang dalam mode kontrol otomatis.
  bool get isAutoMode => pumpMode == PumpMode.auto;

  /// Label mode dalam Bahasa Indonesia untuk ditampilkan pada UI.
  String get modeLabel => isManualMode ? 'Manual' : 'Otomatis';

  /// Mengonversi nilai mentah snapshot Firebase `/monitoring` menjadi [MonitoringData].
  ///
  /// Mengembalikan `null` jika payload kosong/bukan Map atau field wajib
  /// (`soil.moisture` dan `soil.raw`) belum tersedia.
  static MonitoringData? fromSnapshot(Object? value) {
    if (value is! Map) return null;

    // Ambil masing-masing sub-node secara aman (default Map kosong jika belum ada).
    final soil = value['soil'] is Map ? value['soil'] as Map : const {};
    final relay = value['relay'] is Map ? value['relay'] as Map : const {};
    final control = value['control'] is Map
        ? value['control'] as Map
        : const {};

    final moisture = _toInt(soil['moisture']);
    final raw = _toInt(soil['raw']);
    if (moisture == null || raw == null) return null;

    // Default mode adalah AUTO jika node `/monitoring/control/mode` belum dibuat.
    final rawMode = (control['mode'] ?? 'AUTO').toString().trim().toUpperCase();
    final pumpMode = rawMode == 'MANUAL' ? PumpMode.manual : PumpMode.auto;

    return MonitoringData(
      moisture: moisture.clamp(0, 100),
      raw: raw,
      soilStatus: (soil['status'] ?? '-').toString(),
      relayStatus: (relay['status'] ?? 'OFF').toString(),
      pumpMode: pumpMode,
      manualPumpOn: _toBool(control['pump']),
    );
  }

  /// Helper konversi fleksibel dari `num` atau `String` angka menjadi `int`.
  static int? _toInt(Object? value) {
    if (value is num) return value.round();
    if (value is String) return double.tryParse(value.trim())?.round();
    return null;
  }

  /// Helper konversi fleksibel ke `bool` untuk nilai `bool`, `num`, atau teks (`ON`/`TRUE`/`1`).
  static bool _toBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toUpperCase();
      return normalized == 'ON' || normalized == 'TRUE' || normalized == '1';
    }
    return false;
  }
}
