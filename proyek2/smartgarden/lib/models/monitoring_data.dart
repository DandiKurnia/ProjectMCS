enum PumpMode { auto, manual }

class MonitoringData {
  const MonitoringData({
    required this.moisture,
    required this.raw,
    required this.soilStatus,
    required this.relayStatus,
    this.pumpMode = PumpMode.auto,
    this.manualPumpOn = false,
  });

  final int moisture;
  final int raw;
  final String soilStatus;
  final String relayStatus;
  final PumpMode pumpMode;
  final bool manualPumpOn;

  bool get isDry => soilStatus.toUpperCase() == 'DRY';
  bool get isRelayOn => relayStatus.toUpperCase() == 'ON';
  bool get isManualMode => pumpMode == PumpMode.manual;
  bool get isAutoMode => pumpMode == PumpMode.auto;
  String get modeLabel => isManualMode ? 'Manual' : 'Otomatis';

  static MonitoringData? fromSnapshot(Object? value) {
    if (value is! Map) return null;

    final soil = value['soil'] is Map ? value['soil'] as Map : const {};
    final relay = value['relay'] is Map ? value['relay'] as Map : const {};
    final control = value['control'] is Map
        ? value['control'] as Map
        : const {};

    final moisture = _toInt(soil['moisture']);
    final raw = _toInt(soil['raw']);
    if (moisture == null || raw == null) return null;

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

  static int? _toInt(Object? value) {
    if (value is num) return value.round();
    if (value is String) return double.tryParse(value.trim())?.round();
    return null;
  }

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
