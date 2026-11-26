class MonitoringData {
  const MonitoringData({
    required this.moisture,
    required this.raw,
    required this.soilStatus,
    required this.relayStatus,
  });

  final int moisture;
  final int raw;
  final String soilStatus;
  final String relayStatus;

  bool get isDry => soilStatus.toUpperCase() == 'DRY';
  bool get isRelayOn => relayStatus.toUpperCase() == 'ON';

  static MonitoringData? fromSnapshot(Object? value) {
    if (value is! Map) return null;

    final soil = value['soil'] is Map ? value['soil'] as Map : const {};
    final relay = value['relay'] is Map ? value['relay'] as Map : const {};

    final moisture = _toInt(soil['moisture']);
    final raw = _toInt(soil['raw']);
    if (moisture == null || raw == null) return null;

    return MonitoringData(
      moisture: moisture.clamp(0, 100),
      raw: raw,
      soilStatus: (soil['status'] ?? '-').toString(),
      relayStatus: (relay['status'] ?? 'OFF').toString(),
    );
  }

  static int? _toInt(Object? value) {
    if (value is num) return value.round();
    if (value is String) return double.tryParse(value.trim())?.round();
    return null;
  }
}
